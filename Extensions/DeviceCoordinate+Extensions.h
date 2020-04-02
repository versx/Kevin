//
//  DeviceCoordinate+Extensions.h
//  Jarvis++
//
//  Created by versx on 4/2/20.
//

#import "UIImage+Pixels.h"
#import "../Utilities/Utils.h"

@interface DeviceCoordinate (Extensions)

+(BOOL)isAtPixel:(ColorOffset *)min withMax:(ColorOffset *)max;

@end
