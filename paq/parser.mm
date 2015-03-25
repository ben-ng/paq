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
    
    ctx.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        NSLog(@"JS Error: %@", [exception toString]);
    };
    
    unsigned long size;
    char *ACORN_SOURCE = getsectdata("__TEXT", "__acorn_src", &size);
    
    if(size == 0 || strlen(ACORN_SOURCE) == 0) {
        [ctx evaluateScript:@"exports = {parse: function () {return 'acorn is missing from the __TEXT segment'}}"];
    }
    else {
        NSString *concatSource = [@"var exports = {}, module = {exports: exports};" stringByAppendingString:[NSString stringWithCString:ACORN_SOURCE encoding:NSUTF8StringEncoding]];
        
        [ctx evaluateScript:concatSource];
        
        if([ctx[@"exports"][@"parse"] isUndefined] || [ctx[@"exports"][@"parse"] isNull]) {
            [ctx evaluateScript:@"exports = {parse: function () {return 'acorn could not be parsed'}}"];
        }
    }
    
    return ctx;
};
