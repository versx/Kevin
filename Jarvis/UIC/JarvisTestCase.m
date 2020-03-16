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
    @try {
        dispatch_async(dispatch_get_main_queue(), ^{
            [tester enterTextIntoCurrentFirstResponder:text
                                          fallbackView:nil];
        });
    }
    @catch (NSException *exception) {
        NSLog( @"[Jarvis] [JarvisTestCase] type: %@", exception);
    }
}

+(void)touch:(int)x withY:(int)y
{
    NSLog(@"[Jarvis] [Test] touch %d %d", x, y);
    @try {
        dispatch_async(dispatch_get_main_queue(), ^{
            [viewTester tapScreenAtPoint:CGPointMake(x, y)];
        });
    }
    @catch (NSException *exception) {
        NSLog( @"[Jarvis] [JarvisTestCase] touch: %@", exception);
    }
}

+(void)drag:(int)x withY:(int)y
{
    
    //[viewTester tap];
}

@end
