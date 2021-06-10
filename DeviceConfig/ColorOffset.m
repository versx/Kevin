//
//  ColorOffset.m
//  Jarvis++
//
//  Created by versx on 3/22/20.
//

#import "ColorOffset.h"

@implementation ColorOffset

@synthesize red;
@synthesize green;
@synthesize blue;

-(NSString *)description {
    return [NSString stringWithFormat:@"[red=%f green=%f blue=%f]", red, green, blue];
}

-(id)init:(double)red green:(double)green blue:(double)blue
{
    if ((self = [super init])) {
        self.red = red;
        self.green = green;
        self.blue = blue;
    }
    return self;
}

@end
