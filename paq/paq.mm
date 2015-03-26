
//
//  paq.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "paq.h"

NSString * JSONString(NSString *astring) {
    NSMutableString *s = [NSMutableString stringWithString:astring];
    [s replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"/" withString:@"\\/" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\b" withString:@"\\b" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\f" withString:@"\\f" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\r" withString:@"\\r" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\t" withString:@"\\t" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    return [NSString stringWithString:s];
}

Paq::Paq(NSArray *entry, NSDictionary *options) {
    if(entry == nil) {
        [NSException raise:@"INVALID_ARGUMENT" format:@"Paq must be initialized with an NSArray of NSString entry file paths"];
    }
    
    _max_parser_contexts = 6;
    _max_require_contexts = 2;
    _unprocessed = 0;
    _resolve = new Resolve(nil);
    _module_map = [[NSMutableDictionary alloc] initWithCapacity:1000];
    
    _available_parser_contexts = [[NSMutableArray alloc] initWithCapacity:_max_parser_contexts];
    
    for(int i = 0; i < _max_parser_contexts; i++) {
        [_available_parser_contexts addObject:Parser::createContext()];
    }
    
    for(int i = 0; i < _max_require_contexts; i++) {
        [_available_require_contexts addObject:Require::createContext()];
    }
    
    NSMutableArray *mutableEntries = [[NSMutableArray alloc] initWithCapacity:[entry count]];
    
    for(unsigned long i = 0, ii = [entry count]; i<ii; ++i) {
        [mutableEntries addObject:_resolve->path_resolve(@[entry[i]])];
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

void Paq::deps(void (^callback)(NSDictionary *dependencies)) {
    // Called when dependencies are done processing
    _deps_callback = [callback copy];
    
    for(long i=0, ii = [_entry count]; i<ii; ++i) {
        if(_module_map[_entry[i]] == nil) {
            _unprocessed++;
            _module_map[_entry[i]] = [NSNumber numberWithBool:NO];
            deps(_entry[i], _resolve->makeModuleStub(_entry[i]), YES);
        }
    }
}

void Paq::bundle(NSDictionary *options, void (^callback)(NSError *error, NSString *bundle)) {
    _bundle_callback = [callback copy];
    
    // See header file for the structure of the deps callback argument
    deps(^void(NSDictionary *deps) {
        NSString *prelude;
        unsigned long size;
        void *JS_SOURCE = getsectiondata(&_mh_execute_header, "__TEXT", "__prelude_src", &size);
        
        if(size == 0) {
            NSLog(@"The section \"%s\"  is missing from the __TEXT segment", "__prelude_src");
        }
        else {
            prelude = [[NSString alloc] initWithBytesNoCopy:JS_SOURCE length:size encoding:NSUTF8StringEncoding freeWhenDone:NO];
        }
        
        NSMutableString *output = [[NSMutableString alloc] initWithString:prelude];
        
        [output appendString:@"({\n"];
        
        __block unsigned long counter = 0;
        long depscount = [deps count];
        
        NSMutableArray *entryFiles = [[NSMutableArray alloc] initWithCapacity:[_entry count]];
        
        [deps enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSDictionary* obj, BOOL *stop) {
            counter++;
            
            [output appendFormat:@"\"%@\"", JSONString(key)];
            [output appendString:@": [function (require, module, exports) {\n"];
            [output appendString:obj[@"source"]];
            [output appendString:@"\n}, "];
            
            NSError *error;
            NSData *serialized = [NSJSONSerialization dataWithJSONObject:obj[@"deps"] options:0 error:&error];
            
            if(error) {
                [NSException raise:@"Fatal Exception" format:@"The deps object could not be serialized"];
            }
                                  
            [output appendString:[[NSString alloc] initWithData: serialized encoding:NSUTF8StringEncoding]];
            [output appendString:@"]"];
            
            if(counter < depscount) {
                [output appendString:@",\n"];
            }
            
            if([obj[@"entry"] boolValue]) {
                [entryFiles addObject:key];
            }
        }];
        
        [output appendString:@"},{},"];
        
        NSError *error;
        NSData *serialized = [NSJSONSerialization dataWithJSONObject:entryFiles options:0 error:&error];
        
        if(error) {
            [NSException raise:@"Fatal Exception" format:@"The entry array could not be serialized"];
        }
        
        [output appendString:[[NSString alloc] initWithData:serialized encoding:NSUTF8StringEncoding]];
        [output appendString:@")"];
        
        if(options != nil && [options[@"eval"] boolValue]) {
            if([_entry count] != 1) {
                return callback([NSError errorWithDomain:@"com.benng.paq" code:3 userInfo:@{NSLocalizedDescriptionKey: @"The eval option can only be used when there is one entry script"}], nil);
            }
            
            [output appendFormat:@"(\"%@\")", JSONString(_entry[0])];
        }
        
        callback(nil, output);
    });
};

void Paq::deps(NSString *file, NSMutableDictionary *parent, BOOL isEntry) {
    if(!file.isAbsolutePath) {
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
                        for(unsigned long i = 0, ii = [resolved count]; i<ii; ++i) {
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

void Paq::_getAST(NSString *file, void (^callback)(NSDictionary *ast, NSString* source)) {
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

void Paq::_findRequires(NSString *file, NSDictionary *ast, void (^callback)(NSArray *requires)) {
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

void Paq::_resolveRequires(NSArray *requires, NSMutableDictionary *parent, void (^callback)(NSArray *resolved)) {
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