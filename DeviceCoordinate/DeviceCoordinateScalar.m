//
//  DeviceCoordinateScalar.m
//  Jarvis++
//
//  Created by versx on 3/22/20.
//

#import "DeviceCoordinateScalar.h"

@implementation DeviceCoordinateScalar

@synthesize widthNow;
@synthesize heightNow;
@synthesize widthTarget;
@synthesize heightTarget;
@synthesize multiplier;
@synthesize tapMultiplier;

-(NSString *)description {
    return [NSString stringWithFormat:@"[widthNow=%d heightNow=%d widthTarget=%d heightTarget=%d multiplier=%f tapMultiplier=%f]", widthNow, heightNow, widthTarget, heightTarget, multiplier, tapMultiplier];
}

-(id)init:(int)widthNow heightNow:(int)heightNow widthTarget:(int)widthTarget heightTarget:(int)heightTarget multiplier:(double)multiplier tapMultiplier:(double)tapMultiplier
{
    self = [super init];
    if (self) {
        self.widthNow = widthNow;
        self.heightNow = heightNow;
        self.widthTarget = widthTarget;
        self.heightTarget = heightTarget;
        self.multiplier = multiplier;
        self.tapMultiplier = tapMultiplier;
    }
    return self;
}

-(int *)scaleX:(int)x
{
    return lround(x * [self widthNow] / [self widthTarget] * [self multiplier]);
}

-(int *)scaleY:(int)y
{
    return lround(y * [self heightNow] / [self heightTarget] * [self multiplier]);
}

-(int *)tapScaleX:(int)x
{
    return lround(x * [self widthNow] / [self widthTarget] * [self multiplier] * [self tapMultiplier]);
}

-(int *)tapScaleY:(int)y
{
    return lround(y * [self heightNow] / [self heightTarget] * [self multiplier] * [self tapMultiplier]);
}

@end
