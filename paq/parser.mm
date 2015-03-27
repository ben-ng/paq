//
//  parser.mm
//  paq
//
//  Created by Ben on 3/24/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "parser.h"

NSDictionary* Parser::parse(JSContext* ctx, NSString* code, NSError** error)
{
    __block NSError* err;

    ctx.exceptionHandler = ^(JSContext* context, JSValue* exception) {
        err = [NSError errorWithDomain:@"com.benng.paq" code:2 userInfo:@{NSLocalizedDescriptionKey: [exception toString]}];
    };

    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"^#![^\n]*\n" options:0 error:nil];
    code = [regex stringByReplacingMatchesInString:code options:0 range:NSMakeRange(0, [code length]) withTemplate:@""];

    JSValue* parseFunc = ctx[@"parse"];

    JSValue* evalResult = [parseFunc callWithArguments:@[ code ]];

    if (parseFunc == nil) {
        err = [NSError errorWithDomain:@"com.benng.paq" code:8 userInfo:@{ NSLocalizedDescriptionKey : @"A context without a parse function was given to Parser::parse" }];
    }

    if (err) {
        if (error) {
            *error = err;
        }
        return nil;
    }

    if ([evalResult isObject]) {
        return [evalResult toDictionary];
    }
    else if ([evalResult isString]) {
        *error = [NSError errorWithDomain:@"com.benng.paq" code:3 userInfo:@{ NSLocalizedDescriptionKey : [evalResult toString] }];
    }
    else {
        *error = [NSError errorWithDomain:@"com.benng.paq" code:4 userInfo:@{ NSLocalizedDescriptionKey : @"An unknown error occurred, there was no exception and an invalid return value from Acorn" }];
    }

    return nil;
}

JSContext* Parser::createContext()
{
    JSContext* ctx = Script::loadEmbeddedBundle("__acorn_src", @"\
                                      function defined () {\
                                      for (var i = 0; i < arguments.length; i++) {\
                                      if (arguments[i] !== undefined) return arguments[i];\
                                      }}\
                                      function parse (src, opts) {\
                                      if (!opts) opts = {};\
                                      return acorn.parse(src, {\
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

    if (ctx[@"parse"] == nil) {
        [NSException raise:@"Fatal Exception" format:@"A parser context was created without a parse function"];
    }

    return ctx;
};
