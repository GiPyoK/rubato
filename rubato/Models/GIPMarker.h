//
//  GIPMarker.h
//  rubato
//
//  Created by Gi Pyo Kim on 1/9/20.
//  Copyright © 2020 GIPGIP Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_SWIFT_NAME(Marker)
@interface GIPMarker : NSObject

@property Float64 position;
@property UIImage *image;

- (instancetype)initWithPosition:(NSNumber *)position;

@end
