//
//  JSContextExtensions.h
//  paq
//
//  Created by Ben on 3/28/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

class JSContextExtensions {
public:
    static JSContext* create();
    static void destroy(JSContext*);
};
