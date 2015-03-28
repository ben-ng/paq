//
//  main.cpp
//  paq
//
//  Created by Ben on 3/23/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <stdio.h>
#import <iostream>
#import "optionparser.hpp"
#import "paq.h"
#import "resolve.h"

enum optionIndex {
    UNKNOWN = 0,
    PARSER_TASKS,
    REQUIRE_TASKS,
    EVAL,
    STANDALONE,
    CONVERT_BROWSERIFY_TRANSFORM,
    IGNORE_UNRESOLVED_EXPR
};

const option::Descriptor usage[] = {
    { UNKNOWN, 0, "", "", option::Arg::None, "USAGE: paq <entry files> [options]\n\n"
                                             "Options:" },
    { PARSER_TASKS, 0, "", "parserTasks", option::Arg::Optional, "  --parserTasks  \tThe maximum number of concurrent AST parsers" },
    { REQUIRE_TASKS, 0, "", "requireTasks", option::Arg::Optional, "  --requireTasks  \tThe maximum number of concurrent require evaluations" },
    { STANDALONE, 0, "", "standalone", option::Arg::None, "  --standalone  \tReturns a module that exports the entry file's export" },
    { CONVERT_BROWSERIFY_TRANSFORM, 0, "", "convertBrowserifyTransform", option::Arg::None, "  --convertBrowserifyTransform  \tReturns a module that wraps a browserify transform for use with paq" },
    { IGNORE_UNRESOLVED_EXPR, 0, "", "ignoreUnresolvableExpressions", option::Arg::None, "  --ignoreUnresolvableExpressions  \tIgnores expressions in require statements that cannot be statically evaluated" },
    // This just means that we're done defining the usage
    { 0, 0, 0, 0, 0, 0 }
};

int main(int argc, const char* argv[])
{
    NSMutableArray* entry = [[NSMutableArray alloc] init];

    // Parse up to the first option
    int i;

    for (i = 1; i < argc; ++i) {
        if (*argv[i] != '-') {
            [entry addObject:[NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding]];
        }
        else {
            break;
        }
    }

    argc -= i;
    argv += i;
    option::Stats stats(usage, argc, argv);
    option::Option options[5];
    option::Option buffer[5];
    option::Parser parse(usage, argc, argv, options, buffer);

    NSDictionary* optsDict = @{
        @"eval" : [NSNumber numberWithBool:options[EVAL].desc != NULL],
        @"standalone" : [NSNumber numberWithBool:options[STANDALONE].desc != NULL],
        @"convertBrowserifyTransform" : [NSNumber numberWithBool:options[CONVERT_BROWSERIFY_TRANSFORM].desc != NULL],
        @"ignoreUnresolvableExpressions" : [NSNumber numberWithBool:options[IGNORE_UNRESOLVED_EXPR].desc != NULL],
        @"requireTasks" : [NSNumber numberWithBool:options[IGNORE_UNRESOLVED_EXPR].desc != NULL],
    };

    if (([optsDict[@"standalone"] boolValue] ? 1 : 0) + ([optsDict[@"eval"] boolValue] ? 1 : 0) + ([optsDict[@"convertBrowserifyTransform"] boolValue] ? 1 : 0) > 1) {
        NSLog(@"--eval, --standalone, and --convertBrowserifyTransform cannot be used together");
        exit(EXIT_FAILURE);
    }

    if (entry == nil || [entry count] == 0) {
        option::printUsage(std::cout, usage);
        exit(EXIT_SUCCESS);
    }

    Paq* paq = new Paq(entry, optsDict);

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        paq->bundle(optsDict, ^(NSError *error, NSString *bundle) {
            [bundle writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:nil];
            dispatch_semaphore_signal(sem);
        });
    });

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    return 0;
}
