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
#import "PseudoBrowserJSContext.h"

class Script {
public:
    static NSDictionary* getNativeBuiltins();
    static NSString* getModuleRoot();
};
