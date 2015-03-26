//
//  resolve.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "resolve.h"

Resolve::Resolve(NSDictionary* options)
{
    _pathCache = [[NSMutableDictionary alloc] initWithCapacity:1000];
    _realPathCache = [[NSMutableDictionary alloc] initWithCapacity:1000];
    _packageMainCache = [[NSMutableDictionary alloc] initWithCapacity:1000];
    _nativeModules = @[ @"assert",
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
        @"zlib" ];

    if (options != nil && options[@"cwd"]) {
        _cwd = options[@"cwd"];
    }
    else {
        _cwd = [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath] isDirectory:YES];
    }

    NSDictionary* process_env = [[NSProcessInfo processInfo] environment];

    NSString* homeDir = process_env[@"HOME"];
    NSMutableArray* paths = [[NSMutableArray alloc] initWithCapacity:10];
    NSString* process_execPath = NSProcessInfo.processInfo.arguments[0];
    [paths addObject:path_resolve(@[ process_execPath, @"..", @"..", @"lib", @"node" ])];

    if (homeDir) {
        [paths insertObject:path_resolve(@[ homeDir, @".node_libraries" ]) atIndex:0];
        [paths insertObject:path_resolve(@[ homeDir, @".node_modules" ]) atIndex:0];
    }

    NSString* nodePath = process_env[@"NODE_PATH"];
    if (nodePath) {
        NSArray* components = [nodePath componentsSeparatedByString:@"/"];
        for (long i = 0, ii = [components count]; i < ii; ++i) {
            [paths insertObject:components[i] atIndex:i];
        }
    }

    _modulePaths = paths;
};

NSString* Resolve::_resolveFilename(NSString* request, NSMutableDictionary* parent)
{
    if (_nativeModuleExists(request)) {
        return request;
    }

    NSArray* resolvedModule = _resolveLookupPaths(request, parent);
    NSString* id = resolvedModule[0];
    NSArray* paths = resolvedModule[1];

    NSString* filename = _findPath(request, paths);

    if (!filename) {
        NSLog(@"Cannot find module \"%@\"", request);
        NSLog(@"  id: %@", id);

        if (parent && parent[@"filename"]) {
            NSLog(@"  parent: \"%@\"", parent[@"filename"]);
        }

        for (unsigned long i = 0, ii = [paths count]; i < ii; ++i) {
            NSLog(@"tried: %@", paths[i]);
        }

        return nil;
    }

    return filename;
}

NSArray* Resolve::_nodeModulePaths(NSString* from)
{
    NSString* sep = @"/";
    NSMutableArray* paths = [[NSMutableArray alloc] initWithCapacity:20];

    // guarantee that 'from' is absolute
    if (![from isAbsolutePath]) {
        NSString* absstr = [[NSURL URLWithString:from relativeToURL:_cwd] absoluteString];
        from = pathWithoutFileScheme(absstr);
    }

    // Posix only. I doubt this project will ever run on windows anyway.
    NSArray* parts = [from componentsSeparatedByString:sep];

    for (long tip = [parts count] - 1; tip >= 0; tip--) {
        if ([parts[tip] isEqualToString:@"node_modules"]) {
            continue;
        }
        else {
            NSString* dir = [[[parts subarrayWithRange:NSMakeRange(0, tip + 1)] componentsJoinedByString:sep] stringByAppendingPathComponent:@"node_modules"];
            [paths addObject:dir];
        }
    }

    return paths;
};

NSArray* Resolve::_resolveLookupPaths(NSString* request, NSMutableDictionary* parent)
{
    if (_nativeModuleExists(request)) {
        return @[ request, @[] ];
    }

    if (![request hasPrefix:@"./"] && ![request hasPrefix:@".."]) {
        NSArray* paths = _modulePaths;

        if (parent != nil) {
            if (parent[@"paths"] == nil) {
                parent[@"paths"] = @[];
            }
            paths = [parent[@"paths"] arrayByAddingObjectsFromArray:paths];
        }

        return @[ request, paths ];
    }

    // with --eval, parent.id is not set and parent.filename is null
    if (parent == nil || parent[@"id"] == nil || parent[@"filename"] == nil) {
        // make require('./path/to/foo') work - normally the path is taken
        // from realpath(__filename) but with eval there is no filename
        NSArray* mainpaths = [@[ @"." ] arrayByAddingObjectsFromArray:_modulePaths];
        mainpaths = [_nodeModulePaths(@".") arrayByAddingObjectsFromArray:mainpaths];
        return @[ request, mainpaths ];
    }

    // Is the parent an index module?
    // We can assume the parent has a valid extension,
    // as it already has been accepted as a module.
    NSPredicate* isIndexTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^index\\.\\w+?$"];
    BOOL isIndex = [isIndexTest evaluateWithObject:[parent[@"filename"] lastPathComponent]];
    NSString* parentIdPath = isIndex ? parent[@"id"] : [parent[@"id"] stringByDeletingLastPathComponent];
    NSString* id = path_resolve(@[ parentIdPath, request ]);

    if ([parentIdPath isEqualToString:@"."] && [id rangeOfString:@"/"].location == NSNotFound) {
        id = [@"./" stringByAppendingString:id];
    }

    return @[ id, @[ [parent[@"filename"] stringByDeletingLastPathComponent] ] ];
}

NSString* Resolve::_findPath(NSString* request, NSArray* paths)
{
    NSArray* exts = @[ @".js" ];

    if ([request characterAtIndex:0] == '/') {
        paths = @[ @"" ];
    }

    BOOL trailingSlash = [request hasSuffix:@"/"];

    NSString* cacheKey = [[@[ request ] arrayByAddingObjectsFromArray:paths] componentsJoinedByString:@"\0"];
    if (_pathCache[cacheKey] != nil) {
        return _pathCache[cacheKey];
    }

    for (unsigned long i = 0, PL = [paths count]; i < PL; i++) {
        NSString* basePath = path_resolve(@[ paths[i], request ]);
        NSString* filename;

        if (!trailingSlash) {
            // try to join the request to the path
            filename = tryFile(basePath);

            if (!filename && !trailingSlash) {
                // try it with each of the extensions
                filename = tryExtensions(basePath, exts);
            }
        }

        if (!filename) {
            filename = tryPackage(basePath, exts);
        }

        if (!filename) {
            // try it with each of the extensions at "index"
            filename = tryExtensions(path_resolve(@[ basePath, @"index" ]), exts);
        }

        if (filename) {
            _pathCache[cacheKey] = filename;
            return filename;
        }
    }

    return nil;
}

BOOL Resolve::_nativeModuleExists(NSString* request)
{
    return [_nativeModules containsObject:request];
}

NSString* Resolve::path_resolve(NSArray* args)
{
    NSString* resolvedPath = @"";
    BOOL resolvedAbsolute = NO;

    for (long i = [args count] - 1; i >= -1 && !resolvedAbsolute; i--) {
        NSString* path = (i >= 0) ? args[i] : pathWithoutFileScheme(_cwd.absoluteString);

        // Skip empty and invalid entries
        if (path == nil || [path length] == 0) {
            continue;
        }

        resolvedPath = [NSString stringWithFormat:@"%@/%@", path, resolvedPath];
        resolvedAbsolute = [resolvedPath characterAtIndex:0] == '/';
    }

    // At this point the path should be resolved to a full absolute path, but
    // handle relative paths to be safe (might happen when process.cwd() fails)

    // Normalize the path
    resolvedPath = [resolvedPath stringByStandardizingPath];

    if ([resolvedPath isNotEqualTo:@""]) {
        return resolvedPath;
    }
    else {
        return @".";
    }
}

NSMutableDictionary* Resolve::makeModuleStub(NSString* filename)
{
    filename = path_resolve(@[ filename ]);
    return [[NSMutableDictionary alloc] initWithDictionary:@{
        @"id" : filename,
        @"filename" : filename,
        @"paths" : _nodeModulePaths([filename stringByDeletingLastPathComponent])
    }];
}

NSArray* Resolve::normalizeArray(NSArray* parts, BOOL allowAboveRoot)
{
    NSMutableArray* res = [[NSMutableArray alloc] init];

    for (long i = 0, ii = [parts count]; i < ii; i++) {
        NSString* p = parts[i];

        if (!p || [p isEqualToString:@"."]) {
            continue;
        }

        if ([p isEqualToString:@".."]) {
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

NSString* Resolve::tryFile(NSString* requestPath)
{
    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:requestPath isDirectory:&isDirectory];

    if (exists && !isDirectory) {
        char* _realPath = realpath([requestPath cStringUsingEncoding:NSUTF8StringEncoding], NULL);

        if (_realPath == NULL) {
            NSLog(@"Warning: realpath returned NULL for %@", requestPath);

            return nil;
        }
        else {
            NSString* realPath = [NSString stringWithCString:_realPath encoding:NSUTF8StringEncoding];
            free(_realPath);
            _realPathCache[requestPath] = realPath;
            return realPath;
        }
    }
    return nil;
}

NSString* Resolve::tryExtensions(NSString* p, NSArray* exts)
{
    for (unsigned long i = 0, EL = [exts count]; i < EL; i++) {
        NSString* filename = tryFile([p stringByAppendingString:exts[i]]);

        if (filename != nil) {
            return filename;
        }
    }

    return nil;
}

NSString* Resolve::tryPackage(NSString* requestPath, NSArray* exts)
{
    NSDictionary* pkg = readPackage(requestPath);

    if (pkg == nil) {
        return nil;
    }

    NSString* filename = path_resolve(@[ requestPath, pkg ]);
    NSString* temp;

    temp = tryFile(filename);

    if (temp != nil) {
        return temp;
    }

    temp = tryExtensions(filename, exts);

    if (temp != nil) {
        return temp;
    }

    temp = tryExtensions(path_resolve(@[ filename, @"index" ]), exts);

    return temp;
}

NSDictionary* Resolve::readPackage(NSString* requestPath)
{
    if (_packageMainCache[requestPath] != nil) {
        return _packageMainCache[requestPath];
    }

    NSString* jsonPath = path_resolve(@[ requestPath, @"package.json" ]);
    NSError* error;
    NSData* json = [NSData dataWithContentsOfFile:jsonPath options:0 error:&error];

    if (error) {
        // NSLog(@"Encountered an error reading %@: %@", jsonPath, [error localizedDescription]);
        return nil;
    }

    id object = [NSJSONSerialization JSONObjectWithData:json options:0 error:&error];

    if (error) {
        NSLog(@"Encountered an error parsing %@: %@", jsonPath, [error localizedDescription]);
        return nil;
    }

    if ([object isKindOfClass:[NSDictionary class]]) {
        _packageMainCache[requestPath] = ((NSDictionary*)object)[@"main"];
        return _packageMainCache[requestPath];
    }
    else {
        NSLog(@"Parsed %@ but did not get a dictionary: %@", jsonPath, [error localizedDescription]);
        return nil;
    }
}

NSString* Resolve::pathWithoutFileScheme(NSString* path)
{
    unsigned long proto = [@"file://" length];
    NSString* substr = [path substringWithRange:NSMakeRange(proto, [path length] - proto)];

    if ([substr hasPrefix:@"//"]) {
        return [substr substringWithRange:NSMakeRange(1, [substr length] - 1)];
    }
    else {
        return substr;
    }
}
