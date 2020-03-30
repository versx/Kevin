//
//  String+Extensions.m
//  Jarvis++
//
//  Created by versx on 3/27/20.
//

#import "NSString+Extensions.h"

@implementation NSString (Extensions)

+(BOOL)stringIsNullOrEmpty:(NSString *)value
{
    if (!value)
        return true;
    return [value isEqualToString:@""];
}

-(BOOL)isNullOrEmpty
{
    if (self == nil) {
        return true;
    }
    if ([self isMemberOfClass:[NSNull class]]) {
        return true;
    }
    return [self length] == 0;
}

@end
