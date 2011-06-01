//
//  Sound.m
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 3/27/11.
//  Copyright 2011 Multi-Touchy-Feely. All rights reserved.
//

#import "Sound.h"


@implementation Sound

+ (void) soundEffect:(int)soundNumber {
  NSString *effect;
  NSString *type;
  if (soundNumber == 0) {
    // "Swish" sound used when choosing options
    // Taken from free sounds site at http://sounds.beachware.com/
    effect = @"swish";
    type = @"caf";
  }
  else if (soundNumber == 1) {
    effect = @"click";
    type = @"aif";
  }
  else if (soundNumber == 2) {
    effect = @"error";
    type = @"aif";
  }
  
//  NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:@"sound"];
//  if ([value compare:@"ON"] == NSOrderedSame) {
//    
    SystemSoundID soundID;
    
    NSString *path = [[NSBundle mainBundle] pathForResource:effect ofType:type];
    NSURL *url = [NSURL fileURLWithPath:path];
    
    AudioServicesCreateSystemSoundID ((CFURLRef)url, &soundID);
    
    AudioServicesPlaySystemSound(soundID);
//    
//  }
}

- (void)dealloc {
  [super dealloc];
}

@end
