//
//  PreviewViewController.h
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 11/28/10.
//  Copyright 2010 Nano LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AutoScrollLabel.h"


@interface PreviewViewController : UIViewController {
  NSString* userInputText;
  UIFont* textFont;
  IBOutlet UIImageView* previewBackground;
  IBOutlet AutoScrollLabel* textView;
  IBOutlet UILabel* outputLabel;
}

@property (nonatomic, assign) NSString* userInputText;
@property (nonatomic, assign) UIFont* textFont;
@property (nonatomic, retain) UIImageView* previewBackground;
@property (nonatomic, retain) UILabel* outputLabel;
@property (nonatomic, retain) AutoScrollLabel* textView;

/* functions */
- (void)setupPreviewWithOptions;
- (void)fitWordsToScreen:(NSString *)userText;
- (void)autoScrollWithText:(NSString *)userText;
- (void)setFont:(UIFont *)font;
- (void)setBackgroundColor:(UIColor *)color;

@end