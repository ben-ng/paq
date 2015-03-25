//
//  parser.mm
//  paq
//
//  Created by Ben on 3/24/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "parser.h"

NSDictionary* Parser::parse(JSContext* ctx, NSString* code, NSError** error) {
    
    __block bool errored = NO;
    
    ctx.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        errored = YES;
        
        if(error) {
            *error = [NSError errorWithDomain:@"com.benng.paq" code:1 userInfo:@{NSLocalizedDescriptionKey: [exception toString]}];
        }
    };
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^#![^\n]*\n" options:0 error:nil];
    code = [regex stringByReplacingMatchesInString:code options:0 range:NSMakeRange(0, [code length]) withTemplate:@""];
    
    JSValue *parseFunc = ctx[@"parse"];
    
    JSValue *evalResult = [parseFunc callWithArguments:@[code]];
    
    if(errored) {
        return nil;
    }
    
    if([evalResult isObject]) {
        return [evalResult toDictionary];
    }
    else if([evalResult isString]) {
        *error = [NSError errorWithDomain:@"com.benng.paq" code:1 userInfo:@{NSLocalizedDescriptionKey: [evalResult toString]}];
    }
    else {
        *error = [NSError errorWithDomain:@"com.benng.paq" code:1 userInfo:@{NSLocalizedDescriptionKey: @"An unknown error occurred, there was no exception and an invalid return value from Acorn"}];
    }
    
    return nil;
}

JSContext* Parser::createContext() {
    return Script::loadEmbeddedModule("__acorn_src", @"\
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
                                      }");
};
