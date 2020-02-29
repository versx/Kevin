//
//  Jarvis__.m
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#import "Jarvis__.h"
#import "../UIC/UIC.h"

@implementation Jarvis__

-(id)init
{
    NSLog(@"[Jarvis] init");
    if ((self = [super init]))
    {
        NSLog(@"[Jarvis] initializing...");
        UIC2 *uic = [[UIC2 alloc] init];
        [uic start:@8080];
        NSLog(@"[Jarvis] started...");
    }
    
    return self;
}

@end
