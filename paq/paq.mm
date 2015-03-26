
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
    if (entry == nil) {
        [NSException raise:@"INVALID_ARGUMENT" format:@"Paq must be initialized with an NSArray of NSString entry file paths"];
    }

    // Parser contexts are JSContexts with acorn loaded up inside them
    _max_parser_contexts = 6;

    // Require contexts are JSContexts with escodegen loaded up inside them
    _max_require_contexts = 2;

    // When this reaches zero, bundling is done
    _unprocessed = 0;

    // The resolve instance has caches that make resolution faster
    _resolve = new Resolve(nil);

    // The module map keeps track of what modules have been resolved,
    // what requires are contained in each module, if the module is
    // an entry script, and the id of the module, which is typically
    // the filename.
    _module_map = [[NSMutableDictionary alloc] initWithCapacity:1000];

    _available_parser_contexts = [[NSMutableArray alloc] initWithCapacity:_max_parser_contexts];

    // For some reason, if you comment out the following line, shit still works!
    _available_require_contexts = [[NSMutableArray alloc] initWithCapacity:_max_require_contexts];

    for (int i = 0; i < _max_parser_contexts; i++) {
        [_available_parser_contexts addObject:Parser::createContext()];
    }

    for (int i = 0; i < _max_require_contexts; i++) {
        [_available_require_contexts addObject:Require::createContext()];
    }

    NSMutableArray* mutableEntries = [[NSMutableArray alloc] initWithCapacity:[entry count]];

    for (NSUInteger i = 0, ii = [entry count]; i < ii; ++i) {
        [mutableEntries addObject:_resolve->path_resolve(@[ entry[i] ])];
    }

    _entry = mutableEntries;

    _parser_contexts = dispatch_semaphore_create(_max_parser_contexts);
    _require_contexts = dispatch_semaphore_create(_max_require_contexts);

    _serialQ = dispatch_queue_create("paq.serial", DISPATCH_QUEUE_SERIAL);
    _resolveQ = dispatch_queue_create("paq.resolve.serial", DISPATCH_QUEUE_SERIAL);
    _parserCtxQ = dispatch_queue_create("paq.parser-ctx.serial", DISPATCH_QUEUE_SERIAL);
    _requireCtxQ = dispatch_queue_create("paq.require-ctx.serial", DISPATCH_QUEUE_SERIAL);
    _concurrentQ = dispatch_queue_create("paq.concurrent", DISPATCH_QUEUE_CONCURRENT);
};

void Paq::deps(void (^callback)(NSDictionary* dependencies))
{
    // Called when dependencies are done processing
    _deps_callback = [callback copy];

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
    _bundle_callback = [callback copy];

    // See header file for the structure of the deps callback argument
    deps(^void(NSDictionary* deps) {
        Pack::pack(_entry, deps, options, callback);
    });
};

void Paq::deps(NSString* file, NSMutableDictionary* parent, BOOL isEntry)
{
    if (!file.isAbsolutePath) {
        [NSException raise:@"Fatal Exception" format:@"Paq::process must always be called with absolute paths to avoid infinite recursion. You called it with \"%@\"", file];
    }

    dispatch_async(_serialQ, ^{
        _getAST(file, ^(NSDictionary *ast, NSString *source) {
            // Here we are in the parser context queue
            // After this, findRequires enters the require ctx queue
            _findRequires(file, ast, ^(NSArray *requires) {
                // Here we are in the require context queue
                // This will go into the resolve queue
                _resolveRequires(requires, parent, ^(NSArray *resolved) {
                    // Still in the resolve queue
                    // Move to the main serial queue
                    dispatch_async(_serialQ, ^{
                        // Pull together the requires and resolved result for later
                        NSMutableDictionary *zip = [[NSMutableDictionary alloc] initWithCapacity:[resolved count]];
                        for(long i=0, ii=[resolved count]; i<ii; ++i) {
                            zip[requires[i]] = resolved[i];
                        }
                        _module_map[file] = @{@"source": source, @"deps": zip, @"entry": [NSNumber numberWithBool:isEntry]};
                        _unprocessed--;
                        
                        // Dispatch new tasks
                        NSMutableDictionary *parent = _resolve->makeModuleStub(file);
                        for(NSUInteger i = 0, ii = [resolved count]; i<ii; ++i) {
                            if(_module_map[resolved[i]] == nil) {
                                _unprocessed++;
                                _module_map[resolved[i]] = [NSNumber numberWithBool:NO];
                                deps(resolved[i], parent, NO);
                            }
                        }
                        
                        if(_unprocessed == 0) {
                            // See header file for the structure of the deps callback argument
                            _deps_callback(_module_map);
                            Block_release(_deps_callback);
                        }
                    });
                });
            });
        });
    });
}

void Paq::_getAST(NSString* file, void (^callback)(NSDictionary* ast, NSString* source))
{
    dispatch_async(_parserCtxQ, ^{
        dispatch_semaphore_wait(_parser_contexts, 60 * NSEC_PER_SEC);
        JSContext *parserCtx = (JSContext *) [_available_parser_contexts lastObject];
        [_available_parser_contexts removeLastObject];
        
        dispatch_async(_concurrentQ, ^{
            NSError *error;
            NSString *source = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:&error];
            
            if(error) {
                [NSException raise:@"Fatal Exception" format:@"Failed to read source code from %@: %@", file, error.localizedDescription];
            }
            
            NSDictionary *ast = Parser::parse(parserCtx, source, &error);
            
            if(error) {
                [NSException raise:@"Fatal Exception" format:@"Failed to parse source code from %@: %@", file, error.localizedDescription];
            }
            
            dispatch_async(_parserCtxQ, ^{
                [_available_parser_contexts addObject:parserCtx];
                dispatch_semaphore_signal(_parser_contexts);
                callback(ast, source);
            });
        });
    });
};

void Paq::_findRequires(NSString* file, NSDictionary* ast, void (^callback)(NSArray* requires))
{
    dispatch_async(_requireCtxQ, ^{
        dispatch_semaphore_wait(_require_contexts, 60 * NSEC_PER_SEC);
        JSContext *requireCtx = (JSContext *) [_available_require_contexts lastObject];
        [_available_require_contexts removeLastObject];
        
        dispatch_async(_concurrentQ, ^{
            NSError *error;
            NSArray *requires = Require::findRequires(requireCtx, file, ast, &error);
            
            if(error) {
                [NSException raise:@"Fatal Exception" format:@"Failed to find requires in %@: %@", file, error.localizedDescription];
            }
            
            dispatch_async(_requireCtxQ, ^{
                [_available_require_contexts addObject:requireCtx];
                dispatch_semaphore_signal(_require_contexts);
                callback(requires);
            });
        });
    });
}

void Paq::_resolveRequires(NSArray* requires, NSMutableDictionary* parent, void (^callback)(NSArray* resolved))
{
    dispatch_async(_resolveQ, ^{
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
