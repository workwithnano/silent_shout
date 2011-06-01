//
//  EditingViewController.h
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 2/21/11.
//  Copyright 2011 Multi-Touchy-Feely. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TextfieldViewController.h"
#import "FlipsideViewController.h"

@protocol EditingViewControllerDelegate;

@interface EditingViewController : UIViewController <TextfieldViewControllerDelegate, FlipsideViewControllerDelegate> {
  
  TextfieldViewController *textViewController;
  
}

@property (nonatomic, retain) IBOutlet TextfieldViewController *textViewController;

@property (nonatomic, assign) id <EditingViewControllerDelegate> delegate;

@end


@protocol EditingViewControllerDelegate
- (void)editingViewControllerDidFinish:(EditingViewController *)controller;
@end
