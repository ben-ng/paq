//
//  parser.h
//  paq
//
//  Created by Ben on 3/24/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <stdio.h>
#import <string>
#import <mach-o/getsect.h>
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

class Parser {
public:
    static void parse(JSContext* ctx, NSString* code);
    static JSContext* createContext();
};
