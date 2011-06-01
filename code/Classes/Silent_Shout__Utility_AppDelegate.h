//
//  Silent_Shout__Utility_AppDelegate.h
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 8/23/10.
//  Copyright Nano LLC 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class MainViewController;

@interface Silent_Shout__Utility_AppDelegate : NSObject <UIApplicationDelegate> {
  
  UIWindow *window;
  MainViewController *mainViewController;
  UINavigationController *navControl;
  
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet MainViewController *mainViewController;
@property (nonatomic, retain) IBOutlet UINavigationController *navControl;

@end

