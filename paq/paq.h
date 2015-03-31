//
//  paq.h
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "JSContextExtensions.h"
#import "parser.h"
#import "require.h"
#import "resolve.h"
#import "pack.h"

class Paq {
private:
    unsigned long _unprocessed;
    dispatch_queue_t _serialQ;
    Parser* _parser;
    Require* _require;
    Resolve* _resolve;
    NSMutableDictionary* _module_map;
    NSArray* _entry;
    NSDictionary* _options;
    NSDictionary* _nativeModules;

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

    void depsHelper(NSString* file, NSMutableDictionary* parent, BOOL isEntry, void (^callback)(NSDictionary* deps));
    void _getAST(NSString* file, void (^callback)(NSError* err, NSArray* literals, NSArray* expressions, NSString* source));
    void _resolveRequires(NSArray* requires, NSMutableDictionary* parent, void (^callback)(NSArray* resolved));
    NSString* _insertGlobals(NSString* file, NSString* source);

public:
    Paq(NSArray* entry, NSDictionary* options);
    ~Paq();
    /*
     * The main interface between this class and the outside world
     * [options]
     *   [BOOL eval] - If true, the bundle will return the entry script's export
     */
    void bundle(NSDictionary* options, void (^callback)(NSError* error, NSString* bundle));
    NSString* bundleSync(NSDictionary* options, NSError** error);
    NSString* evalToString();
    void deps(void (^callback)(NSDictionary* dependencies));
};
