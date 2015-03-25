//
//  resolve.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "resolve.h"

Resolve::Resolve(NSDictionary *options) {
    _pathCache = [[NSMutableDictionary alloc] initWithCapacity:1000];
    _nativeModules = @[@"assert",
                       @"buffer_ieee754",
                       @"buffer",
                       @"child_process",
                       @"cluster",
                       @"console",
                       @"constants",
                       @"crypto",
                       @"_debugger",
                       @"dgram",
                       @"dns",
                       @"domain",
                       @"events",
                       @"freelist",
                       @"fs",
                       @"http",
                       @"https",
                       @"_linklist",
                       @"module",
                       @"net",
                       @"os",
                       @"path",
                       @"punycode",
                       @"querystring",
                       @"readline",
                       @"repl",
                       @"stream",
                       @"string_decoder",
                       @"sys",
                       @"timers",
                       @"tls",
                       @"tty",
                       @"url",
                       @"util",
                       @"vm",
                       @"zlib"];
    
    if(options != nil && options[@"cwd"]) {
        _cwd = options[@"cwd"];
    }
    else {
        _cwd = [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath] isDirectory:YES];
    }
    
    NSDictionary *process_env = [[NSProcessInfo processInfo] environment];
    
    NSString *homeDir = process_env[@"HOME"];
    NSMutableArray *paths = [[NSMutableArray alloc] initWithCapacity:10];
    NSString *process_execPath = NSProcessInfo.processInfo.arguments[0];
    [paths addObject:path_resolve(@[process_execPath, @"..", @"..", @"lib", @"node"])];
    
    if(homeDir) {
        [paths insertObject:path_resolve(@[homeDir, @".node_libraries"]) atIndex:0];
        [paths insertObject:path_resolve(@[homeDir, @".node_modules"]) atIndex:0];
    }
    
    NSString *nodePath = process_env[@"NODE_PATH"];
    if(nodePath) {
        NSArray *components = [nodePath componentsSeparatedByString:@"/"];
        for(long i=0, ii=[components count]; i<ii; ++i) {
            [paths insertObject:components[i] atIndex:i];
        }
    }
    
    NSLog(@"execPath: %@", process_execPath);
    NSLog(@"homeDir: %@", homeDir);
    
    _modulePaths = paths;
};

NSArray* Resolve::_nodeModulePaths(NSString *from) {
    NSString *sep = @"/";
    NSMutableArray *paths = [[NSMutableArray alloc] initWithCapacity:20];
    
    // guarantee that 'from' is absolute
    if(![from isAbsolutePath]) {
        unsigned long proto = [@"file://" length];
        NSString *absstr = [[NSURL URLWithString:from relativeToURL:_cwd] absoluteString];
        from = [absstr substringWithRange:NSMakeRange(proto, [absstr length] - proto)];
    }
    
    // Posix only. I doubt this project will ever run on windows anyway.
    NSArray *parts = [from componentsSeparatedByString:sep];
    
    for(long tip = [parts count] - 1; tip >= 0; tip--) {
        if([parts[tip] isEqualToString:@"node_modules"]) {
            continue;
        }
        else {
            NSString *dir = [[[parts subarrayWithRange:NSMakeRange(0, tip + 1)] componentsJoinedByString:sep] stringByAppendingPathComponent:@"node_modules"];
            [paths addObject:dir];
        }
    }
    
    return paths;
};

NSArray* Resolve::_resolveLookupPaths(NSString *request, NSMutableDictionary *parent) {
    if (_nativeModuleExists(request)) {
        return @[request, @[]];
    }
    
    if(![request hasPrefix:@"./"] && ![request hasPrefix:@".."]) {
        NSArray *paths = _modulePaths;
        
        if(parent != nil) {
            if (parent[@"paths"] == nil) {
                parent[@"paths"] = @[];
            }
            paths = [parent[@"paths"] arrayByAddingObjectsFromArray:paths];
        }
        
        return @[request, paths];
    }
    
    // with --eval, parent.id is not set and parent.filename is null
    if(parent == nil || parent[@"id"] == nil || parent[@"filename"] == nil) {
        // make require('./path/to/foo') work - normally the path is taken
        // from realpath(__filename) but with eval there is no filename
        NSArray *mainpaths = [@[@"."] arrayByAddingObjectsFromArray:_modulePaths];
        mainpaths = [_nodeModulePaths(@".") arrayByAddingObjectsFromArray:mainpaths];
        return @[request, mainpaths];
    }
    
    // Is the parent an index module?
    // We can assume the parent has a valid extension,
    // as it already has been accepted as a module.
    NSPredicate *isIndexTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^index\\.\\w+?$"];
    BOOL isIndex = [isIndexTest evaluateWithObject:[parent[@"filename"] lastPathComponent]];
    NSString *parentIdPath = isIndex ? parent[@"id"] : [parent[@"id"] stringByDeletingLastPathComponent];
    NSString *id = path_resolve(@[parentIdPath, request]);
    
    if([parentIdPath isEqualToString:@"."] && [id rangeOfString:@"/"].location == NSNotFound) {
        id = [@"./" stringByAppendingString:id];
    }
    
    return @[id, @[[parent[@"filename"] stringByDeletingLastPathComponent]]];
}

BOOL Resolve::_nativeModuleExists(NSString *request) {
    return [_nativeModules containsObject:@"request"];
}

NSString* Resolve::path_resolve(NSArray *args) {
    NSString *resolvedPath = @"";
    BOOL resolvedAbsolute = NO;
    
    for(long i = [args count] -1; i >= -1 && !resolvedAbsolute; i--) {
        NSString *path = (i >= 0) ? args[i] : _cwd.absoluteString;
        
        // Skip empty and invalid entries
        if(path == nil) {
            continue;
        }
        
        resolvedPath = [NSString stringWithFormat:@"%@/%@", path, resolvedPath];
        resolvedAbsolute = [resolvedPath characterAtIndex:0] == '/';
    }
    
    // At this point the path should be resolved to a full absolute path, but
    // handle relative paths to be safe (might happen when process.cwd() fails)
    
    // Normalize the path
    resolvedPath = [normalizeArray([resolvedPath componentsSeparatedByString:@"/"], !resolvedAbsolute) componentsJoinedByString:@"/"];
    
    NSString *ret = [NSString stringWithFormat:@"%@%@", (resolvedAbsolute ? @"/" : @""), resolvedPath];
    
    if([ret isNotEqualTo:@""]) {
        return ret;
    }
    else {
        return @".";
    }
}

NSMutableDictionary *Resolve::makeModuleStub(NSString *filename) {
    return [[NSMutableDictionary alloc] initWithDictionary:@{
            @"id": @".", @"filename": filename, @"paths": _nodeModulePaths([filename stringByDeletingLastPathComponent])}];
}

NSArray* Resolve::normalizeArray(NSArray *parts, BOOL allowAboveRoot) {
    NSMutableArray *res = [[NSMutableArray alloc] init];
    
    for(long i=0, ii=[parts count]; i<ii; i++) {
        NSString *p = parts[i];
        
        if(!p || [p isEqualToString:@"."]) {
            continue;
        }
        
        if([p isEqualToString:@".."]) {
            if ([res count] && [res[[res count] - 1] isNotEqualTo:@".."]) {
                [res removeLastObject];
            }
            else if (allowAboveRoot) {
                [res addObject:@".."];
            }
        }
        else {
            [res addObject:p];
        }
    }
    
    return res;
}
