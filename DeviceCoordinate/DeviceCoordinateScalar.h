//
//  DeviceCoordinateScalar.h
//  Jarvis++
//
//  Created by versx on 3/22/20.
//

@interface DeviceCoordinateScalar : NSObject

@property int widthNow;
@property int heightNow;
@property int widthTarget;
@property int heightTarget;
@property double multiplier;
@property double tapMultiplier;

-(id)init:(int)widthNow heightNow:(int)heightNow
                      widthTarget:(int)widthTarget
                     heightTarget:(int)heightTarget
                       multiplier:(double)multiplier
                    tapMultiplier:(double)tapMultiplier;

-(int *)scaleX:(int)x;
-(int *)scaleY:(int)y;

-(int *)tapScaleX:(int)x;
-(int *)tapScaleY:(int)y;

@end
