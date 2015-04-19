//
//  PseudoBrowserJSContext.h
//  paq
//
//  Created by Ben on 4/19/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <JavaScriptCore/JavaScriptCore.h>

@interface PseudoBrowserJSContext : JSContext

- (PseudoBrowserJSContext*)init;
- (int)setTimeout:(JSValue*)function delay:(JSValue*)delay;
- (int)setInterval:(JSValue*)function delay:(JSValue*)delay;
- (void)clearHandle:(JSValue*)handle;

@property (nonatomic, strong) NSMutableDictionary* handles;
@property (nonatomic) int handle;
@end
