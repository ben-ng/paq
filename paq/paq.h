//
//  paq.h
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "parser.h"
#import "require.h"
#import "resolve.h"

class Paq {
private:
    unsigned int _max_parser_contexts;
    unsigned int _max_require_contexts;
    NSMutableDictionary *_module_map;
    unsigned long _unprocessed;
    NSMutableArray *_available_parser_contexts;
    NSMutableArray *_available_require_contexts;
    NSArray *_entry;
    Resolve *_resolve;
    dispatch_semaphore_t _parser_contexts;
    dispatch_semaphore_t _require_contexts;
    dispatch_queue_t _parserCtxQ;
    dispatch_queue_t _requireCtxQ;
    dispatch_queue_t _resolveQ;
    dispatch_queue_t _serialQ;
    dispatch_queue_t _concurrentQ;
    void (^_bundle_callback)(NSError *error, NSString *bundle);
    
    
    /*
     * This is a map like
     * {
     *      @"/absolute/path.js": @{
     *          @"deps":@[
     *              @[@"requiredExpression", @"/resolved/path.js"]
     *          ],
     *          @"source": @"var some = 'source code';",
     *          @"entry": 1;
     *      }
     *  }
     */
    void (^_deps_callback)(NSDictionary *deps);
    
    void deps(NSString *file, NSMutableDictionary *parent, BOOL isEntry);
    void _getAST(NSString *file, void (^callback)(NSDictionary *ast, NSString *source));
    void _findRequires(NSString *file, NSDictionary *ast, void (^callback)(NSArray *requires));
    void _resolveRequires(NSArray *requires, NSMutableDictionary *parent, void (^callback)(NSArray *resolved));
    NSString * JSONString(NSString *astring);
public:
    Paq(NSArray *entry, NSDictionary *options);
    void bundle(void (^callback)(NSError *error, NSString *bundle));
    void deps(void (^callback)(NSDictionary *dependencies));
};

