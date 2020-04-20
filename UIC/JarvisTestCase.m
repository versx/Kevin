//
//  JarvisTestCase.m
//  Jarvis++
//
//  Created by versx on 3/14/20.
//

#import "JarvisTestCase.h"

@implementation JarvisTestCase

-(id)init
{
    if ((self = [super init])) {
        [self setContinueAfterFailure:true];
        [self setStopTestsOnFirstBigFailure:false];
        [self registerUIInterruptionHandler:@"System Dialog"];
    }
    return self;
}

+(JarvisTestCase *)sharedInstance
{
    static JarvisTestCase *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[JarvisTestCase alloc] init];
    });
    return sharedInstance;
}

-(void)registerUIInterruptionHandler:(NSString*)description {
    syslog(@"[DEBUG] Registering UI interruption handler.");
    [self addUIInterruptionMonitorWithDescription:@"System Dialog"
                                          handler:^BOOL(XCUIElement * _Nonnull interruptingElement) {
        syslog(@"[DEBUG] Interrupting UI element found: %@", interruptingElement);
        NSArray *buttons = [NSArray arrayWithObjects:@"OK", @"Allow", @"Dismiss", @"Trust", @"Not Now", @"Always", @"Later", @"Remind Me Later", @"Close", @"Allow While Using App", nil];
        XCUIElement *element = interruptingElement;
        for (NSString *button in buttons) {
            XCUIElement *btn = element.buttons[button];
            if ([btn exists]) {
                [btn tap];
                [viewTester tap];
                return YES;
            }
        }
        return NO;
    }];
}

+(void)type:(NSString *)text
{
    //syslog(@"[DEBUG] type %@", text);
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
        syslog(@"[ERROR] type: %@", exception);
    }
}

+(void)drag/*FromPoint*/:(DeviceCoordinate *)start toPoint:(DeviceCoordinate *)end
{
    syslog(@"[DEBUG] dragging from %@ to %@", start, end);
    @try {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *window = [[UIApplication sharedApplication] keyWindow];
            UIView *view = [[window rootViewController] view];
            [view dragFromPoint:CGPointMake([start tapX], [start tapY])
                        toPoint:CGPointMake([end tapX], [end tapY]) steps:10]; //8
        });
    }
    @catch (NSException *exception) {
        syslog(@"[ERROR] swipe: %@", exception);
    }
}

+(void)touch:(int)x withY:(int)y
{
    double width = [UIScreen mainScreen].bounds.size.width;
    double height = [UIScreen mainScreen].bounds.size.height;
    if (x > width || y > height) {
        syslog(@"[WARN] Touch coordinates %dx%d are greater than screen size %fx%f", x, y, width, height);
        return;
    }
    //syslog(@"[DEBUG] touch %d %d", x, y);
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
        syslog(@"[ERROR] touch: %@", exception);
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
        syslog(@"[ERROR] clearText: %@", exception);
    }
}

+(void)drag:(int)x withY:(int)y andX:(int)x2 withY:(int)y2
{
    syslog(@"[DEBUG] drag [x=%d y=%d] => [x2=%d y2=%d]", x, y, x2, y2);
    @try {
        [viewTester dragFromPoint:CGPointMake(x, y)
                          toPoint:CGPointMake(x2, y2)
        ];
        //[viewTester tap];
    }
    @catch (NSException *exception) {
        syslog(@"[ERROR] drag: %@", exception);
    }
}

+(void)test
{
    bool result = [UIAutomationHelper acknowledgeSystemAlert];
    syslog(@"[DEBUG] Test result: %@", result ? @"Yes" : @"No");
}

@end
