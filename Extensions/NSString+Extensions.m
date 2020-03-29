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
    return [self length] == 0;
    
    //if ( ( ![myString isEqual:[NSNull null]] ) && ( [myString length] != 0 ) ) {
    //}
    
    //if (!value)
    //    return true;
    //return [value isEqualToString:@""];
    
    //if (!self.length) {
    //    return true;
    //}
    //return false;
    /*
    if (self == nil) {
        return true;
    }
    //if ([self isKindOfClass:[NSNull class]]) {
    if (self == NULL) { // REVIEW: Probably not needed?
        return true;
    }
    return false;
    */
}

@end
