//
//  json.mm
//  paq
//
//  Created by Ben on 3/26/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "json.h"

/**
 * Escapes the string for use in double quotes in js code
 */
NSString* JSONString(NSString* input)
{
    NSArray* tarr = @[ input ];
    if ([NSJSONSerialization isValidJSONObject:tarr]) {
        // Serialize the dictionary
        NSData* json = [NSJSONSerialization dataWithJSONObject:tarr options:0 error:nil];

        // If no errors, let's view the JSON
        if (json != nil) {
            NSMutableCharacterSet* charSet = [[NSMutableCharacterSet alloc] init];
            [charSet addCharactersInString:@"[] "];
            return [[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:charSet];
        }
    }

    return nil;
}
