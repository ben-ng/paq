//
//  parser.mm
//  paq
//
//  Created by Ben on 3/24/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "parser.h"

void Parser::parse(JSContext* ctx, NSString* code, void (^callback)(NSString *err, NSDictionary *ast)) {
    
    __block bool returned = NO;
    
    ctx.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        if(!returned) {
            returned = YES;
            callback([exception toString], nil);
        }
    };
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^#![^\n]*\n" options:0 error:nil];
    code = [regex stringByReplacingMatchesInString:code options:0 range:NSMakeRange(0, [code length]) withTemplate:@""];
    
    JSValue *parseFunc = ctx[@"parse"];
    
    JSValue *evalResult = [parseFunc callWithArguments:@[code]];
    
    if(!returned) {
        if([evalResult isObject]) {
            callback(nil, [evalResult toDictionary]);
        }
        else {
            if([evalResult isString]) {
                callback([evalResult toString], nil);
            }
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
        
        // Wrap acorn's parse function with the settings browserify uses
        // This is lifted from substack's defined and detective modules
        [ctx evaluateScript:@"\
         function defined () {\
         for (var i = 0; i < arguments.length; i++) {\
         if (arguments[i] !== undefined) return arguments[i];\
         }}\
         function parse (src, opts) {\
         if (!opts) opts = {};\
         return exports.parse(src, {\
         ecmaVersion: defined(opts.ecmaVersion, 6),\
         ranges: defined(opts.ranges, opts.range),\
         locations: defined(opts.locations, opts.loc),\
         allowReturnOutsideFunction: defined(\
         opts.allowReturnOutsideFunction, true\
         ),\
         strictSemicolons: defined(opts.strictSemicolons, false),\
         allowTrailingCommas: defined(opts.allowTrailingCommas, true),\
         forbidReserved: defined(opts.forbidReserved, false)\
         });\
         }"];
    }
    
    return ctx;
};
