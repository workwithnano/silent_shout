//
//  MainViewController.h
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 8/23/10.
//  Copyright Nano LLC 2010. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "EditingViewController.h"

@class TexturesSettingsViewController;
@class LetteringSettingsViewController;
@class FontSettingsViewController;

@interface MainViewController : UIViewController <UIScrollViewDelegate,EditingViewControllerDelegate> {
  
  TexturesSettingsViewController *texturesViewController;
  LetteringSettingsViewController *letteringViewController;
  FontSettingsViewController *fontViewController;
  
  UIView *helpView;
  UIView *buttonsView;
  
  UIButton *helpButton;
  
}

- (IBAction)showPreview:(id)sender;
- (IBAction)toggleHelp:(id)sender;

@property(nonatomic, retain) IBOutlet TexturesSettingsViewController *texturesViewController;
@property(nonatomic, retain) IBOutlet LetteringSettingsViewController *letteringViewController;
@property(nonatomic, retain) IBOutlet FontSettingsViewController *fontViewController;

@property(nonatomic, retain) IBOutlet UIView *helpView;
@property(nonatomic, retain) IBOutlet UIView *buttonsView;

@property(nonatomic, retain) IBOutlet UIButton *helpButton;

@end
