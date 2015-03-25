//
//  parser.mm
//  paq
//
//  Created by Ben on 3/24/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "parser.h"

void Parser::parse(JSContext* ctx, NSString* code) {
    JSValue *acornParse = ctx[@"exports"][@"parse"];
    JSValue *ast = [acornParse callWithArguments:@[code]];
    NSLog(@"Returned: %@", ast);
}

JSContext* Parser::createContext() {
    JSContext *ctx = [[JSContext alloc] init];
    ctx.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        NSLog(@"JS Error: %@", exception);
    };
    
    [ctx evaluateScript:@"var exports = {}, module = {exports: exports}"];
    
    unsigned long size;
    char *ACORN_SOURCE = getsectdata("__TEXT", "__acorn_src", &size);
    [ctx evaluateScript:[NSString stringWithCString:ACORN_SOURCE encoding:NSUTF8StringEncoding]];
    return ctx;
};
