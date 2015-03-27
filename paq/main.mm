//
//  main.cpp
//  paq
//
//  Created by Ben on 3/23/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "paq.h"
#import "resolve.h"

int main(int argc, const char* argv[])
{
    NSMutableArray* entry = [[NSMutableArray alloc] init];

    BOOL snipped = NO;

    NSMutableDictionary* options = [[NSMutableDictionary alloc] init];

    // NSProcessInfo does NOT work in this main method when building in release mode for whatever reason
    for (int i = 1; i < argc; i++) {
        NSString* arg = [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];

        if (![arg hasPrefix:@"-"] && !snipped) {
            [entry addObject:arg];
        }

        if ([arg isEqualToString:@"--eval"]) {
            options[@"eval"] = [NSNumber numberWithBool:YES];
            snipped = YES;
        }

        if ([arg isEqualToString:@"--ignoreUnevaluatedExpressions"]) {
            options[@"ignoreUnevaluatedExpressions"] = [NSNumber numberWithBool:YES];
            snipped = YES;
        }
    }

    if (entry == nil || [entry count] == 0) {
        NSLog(@"Usage: paq [entry files] {options}");
        exit(EXIT_SUCCESS);
    }

    Paq* paq = new Paq(entry, options);

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        paq->bundle(options, ^(NSError *error, NSString *bundle) {
            [bundle writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:nil];
            dispatch_semaphore_signal(sem);
        });
    });

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    return 0;
}
