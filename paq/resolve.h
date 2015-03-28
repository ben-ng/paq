//
//  resolve.h
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach-o/getsect.h>
#import <mach-o/ldsyms.h>
#import <iostream>

class Resolve {
private:
    BOOL _nativeModuleExists(NSString* request);
    NSMutableDictionary* _pathCache;
    NSMutableDictionary* _realPathCache;
    NSMutableDictionary* _packageMainCache;
    NSDictionary* _nativeModules;
    NSArray* _modulePaths;
    NSURL* _cwd;
    NSString* tryFile(NSString* requestPath);
    NSString* tryExtensions(NSString* p, NSArray* exts);
    NSString* tryPackage(NSString* requestPath, NSArray* exts);
    NSString* readPackage(NSString* requestPath);
    NSString* pathWithoutFileScheme(NSString* path);

public:
    Resolve(NSDictionary* options);
    ~Resolve();
    NSString* _resolveFilename(NSString* request, NSMutableDictionary* parent);
    NSString* path_resolve(NSArray* args);
    NSMutableDictionary* makeModuleStub(NSString* filename);
    NSArray* normalizeArray(NSArray* parts, BOOL allowAboveRoot);
    NSArray* _nodeModulePaths(NSString* from);
    NSArray* _resolveLookupPaths(NSString* request, NSMutableDictionary* parent);
    NSString* _findPath(NSString* request, NSArray* paths);
};
