//
//  GIPMarker.m
//  rubato
//
//  Created by Gi Pyo Kim on 1/9/20.
//  Copyright © 2020 GIPGIP Studio. All rights reserved.
//

#import "GIPMarker.h"

@implementation GIPMarker

- (instancetype)initWithPosition:(Float64)position {
    self = [super init];
    if (self) {
        _position = position;
        _image = [UIImage imageNamed:@"down-arrow"];
        NSLog(@"%@", _image);
    }
    return self;
}

@end
