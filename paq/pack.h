//
//  pack.h
//  paq
//
//  Created by Ben on 3/26/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach-o/getsect.h>
#import <mach-o/ldsyms.h>
#import "json.h"

class Pack {
public:
    static void pack(NSArray* entry, NSDictionary* deps, NSDictionary* options, void (^callback)(NSError* error, NSString* bundle));
};
