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

class Require {
public:
    static std::vector<std::string> findRequires(JSContext* ctx, NSDictionary *ast, void (^callback)(NSString *err, NSDictionary *ast));
    static JSContext* createContext();
};
