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
    NSMutableDictionary *_realPathCache;
    NSMutableDictionary *_packageMainCache;
    NSArray *_nativeModules;
    NSArray *_modulePaths;
    NSURL *_cwd;
    BOOL _nativeModuleExists(NSString *request);
    NSString *tryFile(NSString *requestPath);
    NSString *tryExtensions(NSString *p, NSArray *exts);
    NSString *tryPackage(NSString *requestPath, NSArray *exts);
    NSDictionary *readPackage(NSString *requestPath);
    NSString *pathWithoutFileScheme(NSString *path);
public:
    Resolve(NSDictionary *options);
    NSString *_resolveFilename(NSString *request, NSMutableDictionary *parent);
    NSString *path_resolve(NSArray *args);
    NSMutableDictionary *makeModuleStub(NSString *filename);
    NSArray* normalizeArray(NSArray *parts, BOOL allowAboveRoot);
    NSArray *_nodeModulePaths(NSString *from);
    NSArray *_resolveLookupPaths(NSString *request, NSMutableDictionary *parent);
    NSString *_findPath(NSString *request, NSArray *paths);
};
