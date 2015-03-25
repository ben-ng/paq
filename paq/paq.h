//
//  paq.h
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>

class Paq {
private:
    unsigned int _max_parser_contexts;
    unsigned int _max_require_contexts;
public:
    Paq(NSArray *entry, NSDictionary *options);
    NSString* bundle();
};
