//
//  traverse.h
//  paq
//
//  Created by Ben on 3/25/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>

class Traverse {
private:
    static void traverse(NSObject *node, void (^callback)(NSObject *node));
    
public:
    static void walk(NSDictionary *root, void (^callback)(NSObject *node));
};
