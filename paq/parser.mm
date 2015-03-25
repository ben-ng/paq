//
//  parser.mm
//  paq
//
//  Created by Ben on 3/24/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "parser.h"

void Parser::parse(JSContext* ctx, NSString* code, void (^callback)(NSString *err, NSDictionary *ast)) {
    ctx.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        callback([exception toString], nil);
    };
    
    JSValue *acornParse = ctx[@"exports"][@"parse"];
    
    JSValue *evalResult = [acornParse callWithArguments:@[code]];
    
    if([evalResult isObject]) {
        callback(nil, [evalResult toDictionary]);
    }
    else {
        if([evalResult isString]) {
            callback([evalResult toString], nil);
        }
    }
}

JSContext* Parser::createContext() {
    JSContext *ctx = [[JSContext alloc] init];
    
    // Also, for some reason, if you don't have this defined, nothing works. Fun!
    ctx.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        NSLog(@"Error creating context: %@", [exception toString]);
    };
    
    [ctx evaluateScript:@"var exports = {}, module = {exports: exports}"];
    
    unsigned long size;
    char *ACORN_SOURCE = getsectdata("__TEXT", "__acorn_src", &size);
    
    if(size == 0 || strlen(ACORN_SOURCE) == 0) {
        [ctx evaluateScript:@"exports.parse = function () {return 'acorn is missing'}"];
    }
    else {
        [ctx evaluateScript:[NSString stringWithCString:ACORN_SOURCE encoding:NSUTF8StringEncoding]];
    }
    
    return ctx;
};
