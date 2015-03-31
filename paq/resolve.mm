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
    _pathCache = nil;
    _realPathCache = nil;
    _packageMainCache = nil;
    _nativeModules = nil;
    _modulePaths = nil;
    _cwd = nil;

    _pathCache = [[NSMutableDictionary alloc] initWithCapacity:1000];
    _realPathCache = [[NSMutableDictionary alloc] initWithCapacity:1000];
    _packageMainCache = [[NSMutableDictionary alloc] initWithCapacity:1000];
    _packageBrowserCache = [[NSMutableDictionary alloc] initWithCapacity:1000];
    _nativeModules = Script::getNativeBuiltins();

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
}

NSString* Resolve::_resolveFilename(NSString* request, NSMutableDictionary* parent, NSError** error)
{
    if (_nativeModuleExists(request)) {
        return request;
    }

    NSArray* resolvedModule = _resolveLookupPaths(request, parent);
    NSString* fileId = resolvedModule[0];
    NSArray* paths = resolvedModule[1];

    NSString* filename = _findPath(request, paths);

    if (!filename) {
        NSMutableString* errString = [[NSMutableString alloc] init];

        [errString appendFormat:@"Cannot resolve module \"%@\"\n", request];
        [errString appendFormat:@"from: %@\n", fileId];

        if (parent && parent[@"filename"]) {
            [errString appendFormat:@"required from: \"%@\"\n", parent[@"filename"]];
        }

        for (NSUInteger i = 0, ii = [paths count]; i < ii; ++i) {
            [errString appendFormat:@"tried: %@\n", paths[i]];
        }

        if (error != nil) {
            *error = [NSError errorWithDomain:@"com.benng.paq" code:17 userInfo:@{ NSLocalizedDescriptionKey : errString }];
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
    /* This is in the node.js source. In paq, everything is absolute, so no worries here.
    if (![from isAbsolutePath]) {
        NSString* absstr = [[NSURL URLWithString:from relativeToURL:_cwd] absoluteString];
        from = pathWithoutFileScheme(absstr);
    }
    */

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
}

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
    /* 
     * This is in the actual node source, but I don't think it works when the entry file is an index module
     * because in node, there is a root module, and that makes this behave differently
     
    NSPredicate* isIndexTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^index\\.\\w+?$"];
    BOOL isIndex = [isIndexTest evaluateWithObject:[parent[@"filename"] lastPathComponent]];
    NSString* parentIdPath = isIndex ? parent[@"id"] : [parent[@"id"] stringByDeletingLastPathComponent];
     
     */

    // We basically just want the directory, so just do this.
    NSString* fileId = path_resolve(@[ [parent[@"filename"] stringByDeletingLastPathComponent], request ]);

    // Root module?
    if ([parent[@"id"] isEqualToString:@"."] && [fileId rangeOfString:@"/"].location == NSNotFound) {
        fileId = [@"./" stringByAppendingString:fileId];
    }

    return @[ fileId, @[ [parent[@"filename"] stringByDeletingLastPathComponent] ] ];
}

NSString* Resolve::_findPath(NSString* request, NSArray* paths)
{
    NSArray* exts = @[ @".js", @".json" ];

    if ([request characterAtIndex:0] == '/') {
        paths = @[ @"" ];
    }

    BOOL trailingSlash = [request hasSuffix:@"/"];

    NSString* cacheKey = [[@[ request ] arrayByAddingObjectsFromArray:paths] componentsJoinedByString:@"\0"];
    if (_pathCache[cacheKey] != nil) {
        return _pathCache[cacheKey];
    }

    for (NSUInteger i = 0, PL = [paths count]; i < PL; i++) {
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
    return _nativeModules[request] != nil;
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
    if (_nativeModuleExists(filename)) {
        filename = _nativeModules[filename];
    }
    else {
        filename = path_resolve(@[ filename ]);
    }

    return [[NSMutableDictionary alloc] initWithDictionary:@{
        @"id" : filename,
        @"filename" : filename,
        @"paths" : _nodeModulePaths([filename stringByDeletingLastPathComponent])
    }];
}

NSString* Resolve::tryFile(NSString* requestPath)
{
    // Preload the browser field replacement dictionary, if there is one
    readPackage(requestPath);

    requestPath = [requestPath stringByStandardizingPath];

    // Replace with browser version if there is one
    if (_packageBrowserCache[requestPath] != nil) {
        requestPath = _packageBrowserCache[requestPath];
    }

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
    for (NSUInteger i = 0, EL = [exts count]; i < EL; i++) {
        NSString* filename = tryFile([p stringByAppendingString:exts[i]]);

        if (filename != nil) {
            return filename;
        }
    }

    return nil;
}

NSString* Resolve::tryPackage(NSString* requestPath, NSArray* exts)
{
    NSString* pkg = readPackage(requestPath);

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

NSString* Resolve::readPackage(NSString* requestPath)
{
    if (_packageMainCache[requestPath] != nil) {
        NSString* mainFile = _packageMainCache[requestPath];
        return [mainFile length] == 0 ? nil : mainFile;
    }

    NSString* jsonPath = path_resolve(@[ requestPath, @"package.json" ]);
    NSError* error = nil;
    NSString* jsonString = [[NSString stringWithContentsOfFile:jsonPath encoding:NSUTF8StringEncoding error:&error] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (jsonString == nil) {
        return nil;
    }

    NSData* json = [jsonString dataUsingEncoding:NSUTF8StringEncoding];

    id object = [NSJSONSerialization JSONObjectWithData:json options:0 error:&error];

    if (object == nil) {
        NSLog(@"Could not parse package.json as json: %@ (%@)\n%@", jsonPath, error.localizedDescription, jsonString);
        return nil;
    }

    if ([object isKindOfClass:[NSDictionary class]]) {
        NSObject* browserFile = ((NSDictionary*)object)[@"browser"];
        NSString* mainFile = ((NSDictionary*)object)[@"main"];
        NSDictionary* browserDict = nil;

        if (browserFile != nil) {
            // If dictionary, write the aliases now
            if ([browserFile isKindOfClass:NSDictionary.class]) {
                browserDict = (NSDictionary*)browserFile;

                [browserDict enumerateKeysAndObjectsUsingBlock:^(NSString* needle, NSString* replacement, BOOL* stop) {
                    // Absolute paths are way easier to work with!
                    NSString* absNeedPath = [[requestPath stringByAppendingPathComponent:needle] stringByStandardizingPath];
                    NSString* absReplPath = [[requestPath stringByAppendingPathComponent:replacement] stringByStandardizingPath];
                    
                    // Make sure that modules can't overwite other modules by traversing upwards
                    if (![absNeedPath hasPrefix:requestPath] || ![absReplPath hasPrefix:requestPath]) {
                        [NSException raise:@"Malicious package.json" format:@"%@ is trying to alter settings beyond its allowed scope", requestPath];
                    }
                    
                    _packageBrowserCache[absNeedPath] = absReplPath;
                }];
            }
            else {
                _packageMainCache[requestPath] = (NSString*)browserFile;
            }
        }

        // Second condition is because a string browser field overrides the main field
        if (mainFile != nil && !_packageMainCache[requestPath]) {
            // Use the browser alias if provided
            if (browserDict && browserDict[mainFile] != nil) {
                _packageMainCache[requestPath] = browserDict[mainFile];
            }
            else {
                _packageMainCache[requestPath] = mainFile;
            }
        }

        if (_packageMainCache[requestPath] == nil) {
            _packageMainCache[requestPath] = @"";
        }

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

Resolve::~Resolve()
{
    _pathCache = nil;
    _realPathCache = nil;
    _packageMainCache = nil;
    _packageBrowserCache = nil;
    _nativeModules = nil;
    _modulePaths = nil;
    _cwd = nil;
}
