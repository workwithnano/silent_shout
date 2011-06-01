//
//  SettingsViewController.h
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 1/17/11.
//  Copyright 2011 Multi-Touchy-Feely. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 Class that creates and controls a UIScrollView as an interactive option selection tool
 @author Neil Anderson http://staticpulse.com/
 */
@interface SettingsViewController : UIViewController <UIScrollViewDelegate> {
  
  NSString* settingName; /**< The name of this setting. Must be one word. Used to save settings */
  
	IBOutlet UIScrollView* scrollView; /**< The UIScrollView to be created and manipulated */
	IBOutlet UIPageControl* pageControl; /**< The UIPageControl which will update and be updated by the UIScrollView */
  NSMutableArray *settings; /**< The array of settings images/animations */
  BOOL pageControlIsChangingPage;/**< Status of the pageControl, important because it prevents UIScrollViewDelegate functions from causing problems by moving the page while already moving the page */
}

@property (nonatomic, retain) NSString *settingName;

@property (nonatomic, retain) UIScrollView *scrollView;
@property (nonatomic, retain) UIPageControl *pageControl;

@property (nonatomic, retain) NSMutableArray *settings;

- (IBAction)changeSettingsPage:(id)sender;

/**
 Runs through all settings images/animations in settings array and attaches them to the SettingsView
 */
- (void)setupSettingsPage;

/**
 Adds an image or animation to the settings array
 All images in the settings need to be the exact same size (I think)
 @param array an array in the following format: [NSString nameOfSetting, UIImage/NSArray image, nil] (don't forget the trailing nil!)
 @returns true if the setting was successfully added
 */
- (BOOL)addSettingArray:(NSArray*)settingArray;

@end
