//
//  resolve.h
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>

class Resolve {
private:
    NSMutableDictionary *_pathCache;
    NSArray *_nativeModules;
    NSURL *_cwd;
public:
    Resolve();
    NSArray *_nodeModulePaths(NSString *from);
    NSArray *_resolveLookupPaths(NSString *request, NSString *parent);
    NSString* resolveRequire(NSString *required, NSString *requiree, NSArray *path);
};
