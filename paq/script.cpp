//
//  script.cpp
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#include "script.h"

JSContext * Script::loadEmbeddedModule(std::string sectionName, NSString *afterLoad) {
    
    JSContext *ctx = [[JSContext alloc] init];
    
    ctx.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        NSLog(@"JS Error: %@", [exception toString]);
    };
    
    unsigned long size;
    char *JS_SOURCE = getsectdata("__TEXT", sectionName.c_str(), &size);
    
    if(size == 0 || strlen(JS_SOURCE) == 0) {
        NSLog(@"The section \"%s\"  is missing from the __TEXT segment", sectionName.c_str());
        [ctx evaluateScript:@"exports = {parse: function () {return 'the script is missing from the __TEXT segment'}}"];
    }
    else {
        NSString *concatSource = [@"var exports = {}, module = {exports: exports};" stringByAppendingString:[NSString stringWithCString:JS_SOURCE encoding:NSUTF8StringEncoding]];
        
        [ctx evaluateScript:concatSource];
        
        if([ctx[@"exports"][@"parse"] isUndefined] || [ctx[@"exports"][@"parse"] isNull]) {
            [ctx evaluateScript:@"exports = {parse: function () {return 'the script could not be parsed'}}"];
        }
        
        if(afterLoad) {
            [ctx evaluateScript:afterLoad];
        }
    }
    
    return ctx;
};
