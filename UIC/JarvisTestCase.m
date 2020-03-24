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
    syslog(@"[DEBUG] type %@", text);
    @try {
        if ([NSThread isMainThread]) {
            [tester enterTextIntoCurrentFirstResponder:text
                                          fallbackView:nil];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [tester enterTextIntoCurrentFirstResponder:text
                                              fallbackView:nil];
            });
        }
    }
    @catch (NSException *exception) {
        syslog(@"[DEBUG] type: %@", exception);
    }
}

+(void)swipe
{
    syslog(@"[DEBUG] swipe up");
    @try {
        dispatch_async(dispatch_get_main_queue(), ^{
            [viewTester swipeInDirection:KIFSwipeDirectionUp];
        });
    }
    @catch (NSException *exception) {
        syslog(@"[DEBUG] swipe: %@", exception);
    }
}

+(void)touch:(int)x withY:(int)y
{
    syslog(@"[DEBUG] touch %d %d", x, y);
    @try {
        if ([NSThread isMainThread]) {
            [viewTester tapScreenAtPoint:CGPointMake(x, y)];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [viewTester tapScreenAtPoint:CGPointMake(x, y)];
            });
        }
    }
    @catch (NSException *exception) {
        syslog(@"[DEBUG] touch: %@", exception);
    }
}

+(void)clearText
{
    syslog(@"[DEBUG] clearText");
    @try {
        dispatch_async(dispatch_get_main_queue(), ^{
            [viewTester clearText];
        });
    }
    @catch (NSException *exception) {
        syslog(@"[DEBUG] clearText: %@", exception);
    }
}

+(void)drag:(int)x withY:(int)y andX:(int)x2 withY:(int)y2
{
    syslog(@"[DEBUG] drag [x=%@ y=%@] => [x2=%@ y2=%@]", x, y, x2, y2);
    @try {
        [viewTester dragFromPoint:CGPointMake(x, y)
                          toPoint:CGPointMake(x2, y2)
        ];
        //[viewTester tap];
    }
    @catch (NSException *exception) {
        syslog(@"[DEBUG] drag: %@", exception);
    }
}

@end
