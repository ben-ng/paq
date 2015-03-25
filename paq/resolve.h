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
    NSArray *_modulePaths;
    NSURL *_cwd;
    BOOL _nativeModuleExists(NSString *request);
public:
    Resolve(NSDictionary *options);
    NSArray *_nodeModulePaths(NSString *from);
    NSArray *_resolveLookupPaths(NSString *request, NSMutableDictionary *parent);
    NSString *resolveRequire(NSString *required, NSString *requiree, NSArray *path);
    NSString *path_resolve(NSArray *args);
    NSMutableDictionary *makeModuleStub(NSString *filename);
    NSArray* normalizeArray(NSArray *parts, BOOL allowAboveRoot);
};
