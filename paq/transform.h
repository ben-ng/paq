//
//  transform.h
//  paq
//
//  Created by Ben on 3/27/15.
//  Copyright (c) 2015 Ben Ng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

class Transform {
private:
    JSContext* _ctx;

public:
    Transform(NSString* transform);
};
