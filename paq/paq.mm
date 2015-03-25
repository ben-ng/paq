//
//  paq.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "paq.h"

Paq::Paq(NSArray *entry, NSDictionary *options) {
    if(entry == nil) {
        [NSException raise:@"INVALID_ARGUMENT" format:@"Paq must be initialized with an NSArray of NSString entry file paths"];
    }
    
    _max_parser_contexts = 6;
    _max_require_contexts = 2;
};

NSString* Paq::bundle() {
    return @"";
};
