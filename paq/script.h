//
//  script.h
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <string>
#import <mach-o/getsect.h>
#import <mach-o/ldsyms.h>
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "JSContextExtensions.h"

class Script {
public:
    // Modules are embedded in the mach-o binary using a linker flag.
    // This helper method makes it easy to load a module into a JSContext.
    static JSContext* loadEmbeddedBundle(std::string sectionName, NSString* afterLoad);
};
