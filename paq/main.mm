//
//  main.cpp
//  paq
//
//  Created by Ben on 3/23/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <stdio.h>
#import <iostream>
#import "paq.h"
#import "resolve.h"

int main(int argc, const char * argv[]) {
    
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    NSArray *entry;
    
    BOOL snipped = NO;
    
    NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
    
    for(unsigned long i = 1, ii = [args count]; i<ii; ++i) {
        if ([args[i] hasPrefix:@"-"] && !snipped) {
            entry = [args subarrayWithRange:NSMakeRange(0, i)];
            snipped = YES;
        }
        
        if ([args[i] isEqualToString:@"--eval"]) {
            options[@"eval"] = [NSNumber numberWithBool:YES];
        }
    }
    
    if(!snipped && [args count]) {
        entry = [args subarrayWithRange:NSMakeRange(1, [args count]-1)];
    }
    
    if(entry == nil) {
        NSLog(@"Usage: paq [entry files] {options}");
        exit(EXIT_SUCCESS);
    }
    
    Paq *paq = new Paq(entry, options);
    
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        paq->bundle(options, ^(NSError *error, NSString *bundle) {
            NSLog(@"%@", bundle);
            dispatch_semaphore_signal(sem);
        });
    });
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    
    return 0;
}
