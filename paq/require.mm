//
//  require.cpp
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "require.h"

JSContext* Require::createContext() {
    return Script::loadEmbeddedModule("__escodegen_src", nil);
};

