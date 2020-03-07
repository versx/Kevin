//
//  Jarvis__.m
//  Jarvis++
//
//  Created by versx on 2/24/20.
//

#import "Jarvis__.h"

@implementation Jarvis__

-(id)init
{
    NSLog(@"[Jarvis] init");
    if ((self = [super init]))
    {
        NSLog(@"[Jarvis] initializing...");
        UIC2 *uic = [[UIC2 alloc] init];
        [uic start];
        NSLog(@"[Jarvis] started...");
    }
    
    return self;
}

@end
