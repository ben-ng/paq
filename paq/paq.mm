
//
//  paq.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "paq.h"

NSString* TRANSFORM_ROOT_FILE = @"transform-root.js";

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
        NSArray* transforms = options[@"transforms"];
        NSMutableDictionary* optionsSansTransforms = [options mutableCopy];
        [optionsSansTransforms removeObjectForKey:@"transforms"];

        for (NSUInteger i = 0, ii = transforms.count; i < ii; ++i) {
            NSError* err = nil;
            Paq* transformBundle = new Paq(@[ _resolve->path_resolve(@[ transforms[i] ]) ], optionsSansTransforms);
            NSString* transformString = transformBundle->bundleSync(@{ @"convertBrowserifyTransform" : [NSNumber numberWithBool:YES] }, &err);

            if (transformString == nil) {
                [NSException raise:@"Fatal Exception" format:@"Failed to paq the %@ transform", transforms[i]];
            }
        }
    }

    // Initialize multithreading stuff
    _serialQ = dispatch_queue_create("paq.serial", DISPATCH_QUEUE_SERIAL);
};

void Paq::deps(NSDictionary* options, void (^callback)(NSDictionary* dependencies))
{
    // Called when dependencies are done processing
    void (^callbackCopy)(NSDictionary*) = [callback copy];
    NSMutableString* generatedRootFile;

    if (options[@"chainTransforms"] != nil && [options[@"chainTransforms"] boolValue]) {
        NSMutableArray* transformFilePaths = [[NSMutableArray alloc] initWithCapacity:_entry.count];
        generatedRootFile = [[NSMutableString alloc] init];

        for (NSUInteger i = 0, ii = _entry.count; i < ii; ++i) {
            NSString* escapedEntry = JSONString(_entry[i]);
            transformFilePaths[i] = [NSString stringWithFormat:@"[%@, require(%@)]", escapedEntry, escapedEntry];
        }

        // First require all the transforms we need
        [generatedRootFile appendFormat:@"var transforms = [\n%@\n]\n", [transformFilePaths componentsJoinedByString:@",\n"]];

        // TODO: Refactor to be more maintainable
        [generatedRootFile appendFormat:@""
                           @"module.exports = function chainedTransform (file, src, finish) {\n"
                           @"  var currentTransformIndex = 0\n"
                           @"    , iterate\n"
                           @"  iterate = function () {\n"
                           @"    var transformFunc\n"
                           @"    if (currentTransformIndex >= transforms.length) {\n"
                           @"      finish(null, src)\n"
                           @"      return\n"
                           @"    }\n"
                           @"    transformFunc = transforms[currentTransformIndex][1]\n"
                           @"    // Handle paq-style transforms\n"
                           @"    if (transformFunc.length === 3) {\n"
                           @"      transformFunc(file, src, function (err, transformedSrc) {\n"
                           @"        if (err) {\n"
                           @"          finish(err, null)\n"
                           @"          return\n"
                           @"        }\n"
                           @"        src = transformedSrc\n"
                           @"        currentTransformIndex += 1\n"
                           @"        iterate()\n"
                           @"      })\n"
                           @"    }\n"
                           @"    // Handle browserify-style transforms\n"
                           @"    else {\n"
                           @"      var transformStream = transformFunc(file)\n"
                           @"        , concat = require('concat-stream')\n"
                           @"      transformStream.pipe(concat(function (data){\n"
                           @"        src = data.toString()\n"
                           @"        currentTransformIndex += 1\n"
                           @"        iterate()\n"
                           @"      }))\n"
                           @"      transformStream.on('error', function (err){\n"
                           @"        finish(err, null)\n"
                           @"      })\n"
                           @"      transformStream.end(src)\n"
                           @"    }\n"
                           @"  }\n"
                           @"  iterate()\n"
                           @"}\n"];

        // There isn't actually a file there, but we pretend like there is one
        // the resolve will give us an absolute path to this fake file
        // wherever the current working directory (cwd) is, so that the require
        // calls in the file contents resolve relative to the cwd
        NSString* rootFile = _resolve->path_resolve(@[ TRANSFORM_ROOT_FILE ]);

        _unprocessed = 1;

        _module_map[rootFile] = [NSNumber numberWithBool:NO];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            depsHelper(rootFile, _resolve->makeModuleStub(rootFile), generatedRootFile, YES, callbackCopy);
        });
    }
    else {
        _unprocessed = _entry.count;

        for (long i = 0, ii = _entry.count; i < ii; ++i) {
            if (_module_map[_entry[i]] == nil) {
                _module_map[_entry[i]] = [NSNumber numberWithBool:NO];

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    depsHelper(_entry[i], _resolve->makeModuleStub(_entry[i]), nil, YES, callbackCopy);
                });
            }
        }
    }
}

void Paq::bundle(NSDictionary* options, void (^callback)(NSError* error, NSString* bundle))
{
    __block void (^cbref)(NSError*, NSString* bundle) = [callback copy];

    // See header file for the structure of the deps callback argument
    deps(options, ^void(NSDictionary* deps) {
        if (options[@"chainTransforms"] != nil && [options[@"chainTransforms"] boolValue]) {
            // Transform bundles are actually standalone modules
            NSMutableDictionary *optionsCopy = [options mutableCopy];
            optionsCopy[@"standalone"] = [NSNumber numberWithBool:YES];
            
            Pack::pack(@[_resolve->path_resolve(@[TRANSFORM_ROOT_FILE])], deps, optionsCopy, cbref);
        }
        else {
            Pack::pack(_entry, deps, options, cbref);
        }
        cbref = nil;
    });
};

void Paq::depsHelper(NSString* file, NSMutableDictionary* parent, NSString* source, BOOL isEntry, void (^callback)(NSDictionary* deps))
{
    if (!file.isAbsolutePath) {
        [NSException raise:@"Fatal Exception" format:@"Paq::deps must always be called with absolute paths to avoid infinite recursion. You called it with \"%@\"", file];
    }

    // This stuff can be done concurrently
    _getAST(file, source, ^(NSError* err, NSArray* literals, NSArray* expressions, NSString* source) {
        if(literals == nil || expressions == nil || source == nil) {
            // TODO: Fail more gracefully here
            [NSException raise:@"Fatal Exception" format:@"Dependency resolution failed: %@", err];
        }
        
        // Here we are in some concurrent queue
        _require->evaluateRequireExpressions(file, expressions, ^(NSError *error, NSArray *evaluatedExpressions) {
            // Still in some concurrent queue here
            
            // Probably some problem with evaluating a require expression or something
            if (evaluatedExpressions == nil) {
                NSLog(@"Failed to resolve requires: %@", error.localizedDescription);
                exit(EXIT_FAILURE);
            }
            
            NSArray *evaluatedRequires = [literals arrayByAddingObjectsFromArray:evaluatedExpressions];
            
            // Still in a concurrent queue
            _resolveRequires(evaluatedRequires, parent, ^(NSArray* resolved) {
                // Still in the resolve queue
                // Move to the main serial queue
                dispatch_async(_serialQ, ^{
                    
                    // Pull together the requires and resolved result for later
                    NSMutableDictionary *zip = [[NSMutableDictionary alloc] initWithCapacity:[resolved count]];
                    for(long i=0, ii=[resolved count]; i<ii; ++i) {
                        NSString* possibleNativeModule = _nativeModules[resolved[i]];
                        
                        if(possibleNativeModule != nil) {
                            zip[evaluatedRequires[i]] = possibleNativeModule;
                        }
                        else {
                            zip[evaluatedRequires[i]] = resolved[i];
                        }
                    }
                    
                    // Dispatch new tasks for each new module
                    for(NSUInteger i = 0, ii = [resolved count]; i<ii; ++i) {
                        // If resolved[i] == file then it is the one we just resolved
                        NSMutableDictionary *parent = _resolve->makeModuleStub(resolved[i]);
                        NSString *path = parent[@"filename"];
                        if(![resolved[i] isEqualToString: @"\0"] && // These are modules ignored using `false` in the package.json browser field
                           _module_map[path] == nil &&
                           resolved[i] != file) {
                            _unprocessed++;
                            _module_map[path] = [NSNumber numberWithBool:NO]; // This ensures that nobody else tries to resolve this
                            depsHelper(path, parent, nil, NO, callback);
                        }
                    }
                    
                    // Must decrement after dispatching because on slow machines with few threads, those tasks ^
                    // may complete before we do. By decrementing last, we ensure that we keep _unprocessed above zero
                    // and that we are definitely the last task to complete
                    _module_map[file] = @{@"source": source, @"deps": zip, @"entry": [NSNumber numberWithBool:isEntry]};
                    _unprocessed--;
                    
                    // callback could be nil if the object gets deallocated before it is called?
                    // TODO:: only a maybe. try removing this later.
                    if(_unprocessed == 0 && callback != nil) {
                        // See header file for the structure of the deps callback argument
                        callback(_module_map);
                    }
                });
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

void Paq::_getAST(NSString* file, NSString* source, void (^callback)(NSError* err, NSArray* literals, NSArray* expressions, NSString* source))
{
    __block NSString* srcCode = nil;

    if (source == nil) {
        dispatch_fd_t fd = open([file cStringUsingEncoding:NSUTF8StringEncoding], O_RDONLY);

        if (fd == -1) {
            return callback([NSError errorWithDomain:@"com.benng.paq" code:17 userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"errno %d opening %@", errno, file] }], nil, nil, nil);
        }

        dispatch_semaphore_t readsema = dispatch_semaphore_create(0);

        dispatch_read(fd, SIZE_T_MAX, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(dispatch_data_t data, int error) {
            int res = close(fd);
            
            if(res != 0) {
                return callback([NSError errorWithDomain:@"com.benng.paq" code:18 userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"errno %d closing file", errno] }], nil, nil, nil);
            }
            
            if(error != 0) {
                return callback([NSError errorWithDomain:@"com.benng.paq" code:16 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Error %d in dispatch_read of %@", error, file]}], nil, nil, nil);
            }
            
            srcCode = [[NSString alloc] initWithData:(NSData *) data encoding:NSUTF8StringEncoding];
            
            if ([file.pathExtension isEqualToString:@"json"]) {
                srcCode = [@"module.exports=" stringByAppendingString:srcCode];
            }
            
            dispatch_semaphore_signal(readsema);
        });

        dispatch_semaphore_wait(readsema, DISPATCH_TIME_FOREVER);
    }
    else {
        srcCode = source;
    }

    // Insert globals now, because the replacements have require calls in them
    srcCode = _insertGlobals(file, srcCode);

    _parser->parse(srcCode, callback);
};

void Paq::_resolveRequires(NSArray* requires, NSMutableDictionary* parent, void (^callback)(NSArray* resolved))
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *resolved = [[NSMutableArray alloc] initWithCapacity:[requires count]];
        
        for (long i = 0, ii = [requires count]; i<ii; ++i) {
            NSError* error = nil;
            NSString *result = _resolve->_resolveFilename(requires[i], parent, &error);
            
            if(!result) {
                [NSException raise:@"Fatal Exception" format:@"%@", error];
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
            NSLog(@"Error bundling: %@", err);
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

    JSContext* ctx = [[PseudoBrowserJSContext alloc] init];

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
    delete _resolve;
    delete _require;
}
