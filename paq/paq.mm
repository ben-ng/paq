
//
//  paq.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "paq.h"

Paq::Paq(NSArray* entry, NSDictionary* options)
{
    _unprocessed = 0;
    _serialQ = nil;
    _parser = nil;
    _resolve = nil;
    _module_map = nil;
    _entry = nil;
    _options = nil;
    _nativeModules = nil;
    _deps_callback = nil;

    if (entry == nil) {
        [NSException raise:@"INVALID_ARGUMENT" format:@"Paq must be initialized with an NSArray of NSString entry file paths"];
    }

    _parser = new Parser(@{ @"maxTasks" : options && options[@"parserTasks"] ? options[@"parserTasks"] : [NSNumber numberWithInt:0] });
    _require = new Require(@{
        @"maxTasks" : options && options[@"requireTasks"] ? options[@"requireTasks"] : [NSNumber numberWithInt:0],
        @"ignoreUnresolvableExpressions" : [NSNumber numberWithBool:options && options[@"ignoreUnresolvableExpressions"] && [options[@"ignoreUnresolvableExpressions"] boolValue]]
    });

    // When this reaches zero, bundling is done
    _unprocessed = 0;

    // The module map keeps track of what modules have been resolved,
    // what requires are contained in each module, if the module is
    // an entry script, and the id of the module, which is typically
    // the filename.
    _module_map = [[NSMutableDictionary alloc] initWithCapacity:1000];

    // Load up the shims for node core modules
    _nativeModules = Script::getNativeBuiltins();

    // The resolve instance has caches that make resolution faster
    _resolve = new Resolve(@{ @"nativeModules" : _nativeModules });

    // Resolve paths to entry files
    NSMutableArray* mutableEntries = [[NSMutableArray alloc] initWithCapacity:[entry count]];

    for (NSUInteger i = 0, ii = entry.count; i < ii; ++i) {
        [mutableEntries addObject:_resolve->path_resolve(@[ entry[i] ])];
    }

    _entry = mutableEntries;
    _options = options;

    // Are there any transforms we need to set up?
    if (options && options[@"transforms"]) {
        if (![options[@"transforms"] isKindOfClass:NSArray.class]) {
            [NSException raise:@"Fatal Exception" format:@"The transforms option must be an NSArray"];
        }

        // paq each transform
    }

    // Initialize multithreading stuff
    _serialQ = dispatch_queue_create("paq.serial", DISPATCH_QUEUE_SERIAL);
};

void Paq::deps(void (^callback)(NSDictionary* dependencies))
{
    // Called when dependencies are done processing
    _deps_callback = [callback copy]g;

    for (long i = 0, ii = [_entry count]; i < ii; ++i) {
        if (_module_map[_entry[i]] == nil) {
            _unprocessed++;
            _module_map[_entry[i]] = [NSNumber numberWithBool:NO];
            deps(_entry[i], _resolve->makeModuleStub(_entry[i]), YES);
        }
    }
}

void Paq::bundle(NSDictionary* options, void (^callback)(NSError* error, NSString* bundle))
{
    __block void (^cbref)(NSError*, NSString* bundle) = [callback copy];

    // See header file for the structure of the deps callback argument
    deps(^void(NSDictionary* deps) {
        Pack::pack(_entry, deps, options, cbref);
        cbref = nil;
    });
};

void Paq::deps(NSString* file, NSMutableDictionary* parent, BOOL isEntry)
{
    if (!file.isAbsolutePath) {
        [NSException raise:@"Fatal Exception" format:@"Paq::deps must always be called with absolute paths to avoid infinite recursion. You called it with \"%@\"", file];
    }

    dispatch_async(_serialQ, ^{
        NSDictionary *ast = nil;
        NSString *source = nil;
        NSError *err = nil;
        NSArray *parseResult = _getAST(file, &err);
        
        if(parseResult == nil) {
            if(err != nil) {
                NSLog(@"Failing because of error: %@", err.localizedDescription);
            }
            exit(EXIT_FAILURE);
        }
        
        ast = parseResult[0];
        source = parseResult[1];
        
        // Here we are in the parser context queue
        // After this, findRequires enters the require ctx queue
        NSArray *requires = _require->findRequires(file, ast, &err);
        
        // Probably some problem with evaluating a require expression or something
        if(requires == nil) {
            NSLog(@"%@", err.localizedDescription);
            exit(EXIT_FAILURE);
        }
        
        // This will go into a concurrent queue
        _resolveRequires(requires, parent, ^(NSArray *resolved) {
            // Do nothing if deallocated
            if (this == nil) {
                return;
            }
            
            // Still in the resolve queue
            // Move to the main serial queue
            dispatch_async(_serialQ, ^{
                // Pull together the requires and resolved result for later
                NSMutableDictionary *zip = [[NSMutableDictionary alloc] initWithCapacity:[resolved count]];
                for(long i=0, ii=[resolved count]; i<ii; ++i) {
                    zip[requires[i]] = resolved[i];
                    
                    // Add native modules to the map as they are discovered
                    if(_nativeModules[resolved[i]] != nil && _module_map[resolved[i]] == nil) {
                        _module_map[resolved[i]] = @{@"source": _nativeModules[resolved[i]], @"deps": @{}, @"entry": [NSNumber numberWithBool:NO]};
                    }
                }
                
                // Dispatch new tasks for each new module
                for(NSUInteger i = 0, ii = [resolved count]; i<ii; ++i) {
                    // If resolved[i] == file then it is the one we just resolved
                    if(_module_map[resolved[i]] == nil && resolved[i] != file) {
                        NSMutableDictionary *parent = _resolve->makeModuleStub(resolved[i]);
                        _unprocessed++;
                        _module_map[resolved[i]] = [NSNumber numberWithBool:NO];
                        deps(resolved[i], parent, NO);
                    }
                }
                
                // Must decrement after dispatching because on slow machines with few threads, those tasks ^
                // may complete before we do. By decrementing last, we ensure that we keep _unprocessed above zero
                // and that we are definitely the last task to complete
                _module_map[file] = @{@"source": source, @"deps": zip, @"entry": [NSNumber numberWithBool:isEntry]};
                _unprocessed--;
                
                // _deps_callback could be nil if the object gets deallocated before it is called
                if(_unprocessed == 0 && _deps_callback != nil) {
                    // See header file for the structure of the deps callback argument
                    _deps_callback(_module_map);
                    _deps_callback = nil;
                }
            });
        });
    });
}

NSString* Paq::_insertGlobals(NSString* file, NSString* source)
{
    NSMutableArray* globalKeysToDefine = [[NSMutableArray alloc] init];
    NSMutableArray* globalValuesToDefine = [[NSMutableArray alloc] init];

    // Not sure if its worth parsing the AST more smartly or not.

    if ([source rangeOfString:@"process"].location != NSNotFound) {
        [globalKeysToDefine addObject:@"process"];
        [globalValuesToDefine addObject:@"require('process')"];
    }

    if ([source rangeOfString:@"global"].location != NSNotFound) {
        [globalKeysToDefine addObject:@"global"];
        [globalValuesToDefine addObject:@"typeof global !== 'undefined' ? global : typeof self !== 'undefined' ? self : typeof window !== 'undefined' ? window : {}"];
    }

    if ([source rangeOfString:@"Buffer"].location != NSNotFound) {
        [globalKeysToDefine addObject:@"Buffer"];
        [globalValuesToDefine addObject:@"require('buffer').Buffer"];
    }

    if ([source rangeOfString:@"__filename"].location != NSNotFound) {
        [globalKeysToDefine addObject:@"__filename"];
        [globalValuesToDefine addObject:JSONString(file)];
    }

    if ([source rangeOfString:@"__dirname"].location != NSNotFound) {
        [globalKeysToDefine addObject:@"__dirname"];
        [globalValuesToDefine addObject:JSONString([file stringByDeletingLastPathComponent])];
    }

    if ([globalKeysToDefine count] > 0) {
        // r as in replacement
        NSMutableString* r = [[NSMutableString alloc] init];
        [r appendString:@"(function ("];
        [r appendString:[globalKeysToDefine componentsJoinedByString:@","]];
        [r appendString:@"){\n"];
        [r appendString:source];
        [r appendString:@"\n}).call(this,"];
        [r appendString:[globalValuesToDefine componentsJoinedByString:@","]];
        [r appendString:@")\n"];
        return r;
    }

    return source;
}

NSArray* Paq::_getAST(NSString* file, NSError** error)
{
    NSError* err;
    NSString* source = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:&err];

    if (source == nil) {
        if (error && err != nil) {
            *error = err;
        }
        return nil;
    }

    if ([file.pathExtension isEqualToString:@"json"]) {
        source = [@"module.exports=" stringByAppendingString:source];
    }

    // Insert globals now, because the replacements have require calls in them
    source = _insertGlobals(file, source);

    NSDictionary* ast = _parser->parse(source, &err);

    if (ast == nil) {
        if (error && err != nil) {
            *error = err;
        }
        return nil;
    }

    return @[ ast, source ];
};

void Paq::_resolveRequires(NSArray* requires, NSMutableDictionary* parent, void (^callback)(NSArray* resolved))
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *resolved = [[NSMutableArray alloc] initWithCapacity:[requires count]];
        
        for (long i = 0, ii = [requires count]; i<ii; ++i) {
            NSString *result = _resolve->_resolveFilename(requires[i], parent);
            
            if(!result) {
                [NSException raise:@"Fatal Exception" format:@"Module not found"];
            }
            
            [resolved addObject:result];
        }
        
        callback(resolved);
    });
}

NSString* Paq::bundleSync(NSDictionary* options, NSError** error)
{
    __block NSString* bundled;
    __block NSError* err = nil;

    dispatch_semaphore_t semab = dispatch_semaphore_create(0);

    bundle(options, ^(NSError* erred, NSString* bundle) {
        if(erred) {
            err = erred;
        }
        else {
            bundled = bundle;
        }
        dispatch_semaphore_signal(semab);
    });

    dispatch_semaphore_wait(semab, DISPATCH_TIME_FOREVER);

    if (err) {
        if (error) {
            *error = err;
        }
        else {
            NSLog(@"Error bundling: %@", err.localizedDescription);
        }
        return nil;
    }
    else {
        return bundled;
    }
}

NSString* Paq::evalToString()
{
    NSError* err = nil;
    __block NSString* except;
    NSString* bundle = bundleSync(@{ @"eval" : [NSNumber numberWithBool:YES] }, &err);

    if (bundle == nil) {
        return err.localizedDescription;
    }

    JSContext* ctx = JSContextExtensions::create();

    ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
        except = [exception toString];
    };

    JSValue* result = [ctx evaluateScript:bundle];

    ctx.exceptionHandler = nil;

    return except ? except : [result toString];
}

Paq::~Paq()
{
    _serialQ = nil;
    _resolve = nil;
    _module_map = nil;
    _entry = nil;
    _options = nil;
    _nativeModules = nil;
    _deps_callback = nil;
    delete _resolve;
    delete _require;
}
