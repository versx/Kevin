//
//  String+Extensions.m
//  Jarvis++
//
//  Created by versx on 3/27/20.
//

#import "NSString+Extensions.h"

@implementation NSString (Extensions)

-(BOOL)isNullOrEmpty
{
    return self == nil || self.length == 0;
}

@end
