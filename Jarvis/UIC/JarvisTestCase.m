//
//  JarvisTestCase.m
//  Jarvis++
//
//  Created by versx on 3/14/20.
//

#import "JarvisTestCase.h"

@implementation JarvisTestCase

+(void)type:(NSString *)text
{
    NSLog(@"[Jarvis] [Test] type %@", text);
    [tester enterTextIntoCurrentFirstResponder:text];
}

+(void)touch:(int)x withY:(int)y
{
    NSLog(@"[Jarvis] [Test] touch %d %d", x, y);
    [tester tapScreenAtPoint:CGPointMake(x, y)];
}

@end
