//
//  traverse.mm
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import "traverse.h"

void Traverse::walk(NSDictionary* root, void (^callback)(NSDictionary* node))
{
    traverse(root, callback);
}

void Traverse::traverse(NSObject* node, void (^callback)(NSDictionary* node))
{
    if ([node isKindOfClass:NSArray.class]) {
        NSArray* arrNode = (NSArray*)node;

        for (NSUInteger i = 0, ii = [arrNode count]; i < ii; ++i) {
            if (arrNode[i] != nil) {
                traverse(arrNode[i], callback);
            }
        }
    }
    else if (node && [node isKindOfClass:NSDictionary.class]) {
        NSDictionary* dictNode = (NSDictionary*)node;

        callback(dictNode);

        [dictNode enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL* stop) {
            traverse(obj, callback);
        }];
    }
}
