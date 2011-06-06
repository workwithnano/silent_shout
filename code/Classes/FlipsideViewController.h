//
//  FlipsideViewController.h
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 8/23/10.
//  Copyright Nano LLC 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AutoScrollLabel.h"

@protocol FlipsideViewControllerDelegate;


@interface FlipsideViewController : UIViewController {
	id <FlipsideViewControllerDelegate> delegate;
  NSString* userInputText;
  IBOutlet AutoScrollLabel* textView;
  IBOutlet UILabel* outputLabel;
  IBOutlet UIToolbar* toolbar;
  
  IBOutlet UIWebView* outputWebView; /**< The webview which will display the output contents */
  
  IBOutlet UIImageView* bgImage;
}

@property (nonatomic, assign) id <FlipsideViewControllerDelegate> delegate;
@property (nonatomic, assign) NSString* userInputText;
@property (nonatomic, retain) UILabel* outputLabel;
@property (nonatomic, retain) AutoScrollLabel* textView;
@property (nonatomic, retain) UIScrollView* swipeView;
@property (nonatomic, retain) UIToolbar* toolbar;

@property (nonatomic, retain) UIWebView* outputWebView;

@property (nonatomic, retain) UIImageView* bgImage;

- (IBAction)back:(id)sender;
- (IBAction)doubleBack:(id)sender;
- (IBAction)saveToCameraRoll:(id)sender;

- (void)autoScrollWithText:(NSString *)userText;

@end


@protocol FlipsideViewControllerDelegate
- (void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller returnToStart:(BOOL)userWantsToGoBackToStart;
@end

