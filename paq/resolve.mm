//
//  resolve.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "resolve.h"

Resolve::Resolve() {
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
    _cwd = [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath] isDirectory:YES];
};

NSArray* Resolve::_nodeModulePaths(NSString *from) {
    NSString *sep = @"/";
    NSMutableArray *paths = [[NSMutableArray alloc] initWithCapacity:20];
    
    // guarantee that 'from' is absolute
    if(![from isAbsolutePath]) {
        from = [[NSURL URLWithString:from relativeToURL:_cwd] absoluteString];
    }
    
    // Posix only. I doubt this project will ever run on windows anyway.
    NSArray *parts = [from componentsSeparatedByString:sep];
    
    for(long tip = [parts count] - 1; tip >= 0; --tip) {
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
