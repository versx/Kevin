//
//  JarvisTestCase.h
//  Jarvis++
//
//  Created by versx on 3/14/20.
//

#import <CoreLocation/CoreLocation.h>
#import <KIF/KIFUIViewTestActor.h>
#import <KIF/XCTestCase-KIFAdditions.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UIKit.h>

@interface JarvisTestCase : KIFTestCase

+(void)type:(NSString *)text;
+(void)touch:(int)x withY:(int)y;
+(void)swipe;

@end
