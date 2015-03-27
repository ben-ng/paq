//
//  require.h
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <vector>
#import <string>
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "script.h"
#import "traverse.h"
#import "json.h"

class Require {
private:
    static bool isRequire(NSDictionary* node);

public:
    static NSArray* findRequires(JSContext* ctx, NSString* path, NSDictionary* ast, NSDictionary* options, NSError** error);
    static JSContext* createContext(NSString* pathModuleSrc);
};
