//
//  TextfieldViewController.h
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 9/20/10.
//  Copyright 2010 Nano LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol TextfieldViewControllerDelegate;

// Forward declaration
@class PreviewViewController;

@interface TextfieldViewController : UIViewController <UITextFieldDelegate>{
  
	id <TextfieldViewControllerDelegate> delegate;
  PreviewViewController *previewViewController;
	IBOutlet UITextField* mainTextField;
  IBOutlet UIButton* keyboardButton;
  IBOutlet UIButton* textfieldButton;

}

@property (nonatomic, assign) id <TextfieldViewControllerDelegate> delegate;
@property (nonatomic, retain) IBOutlet PreviewViewController *previewViewController;
@property (nonatomic, retain) IBOutlet UITextField *mainTextField;
@property (nonatomic, retain) IBOutlet UIButton *keyboardButton;
@property (nonatomic, retain) IBOutlet UIButton *textfieldButton;

- (IBAction) toggleTextfieldEditor:(id)sender;
- (IBAction) beginEditingMode:(id)sender;
- (IBAction) textfieldUpdated:(id)sender;

- (void)setupTextfield;
- (void)moveTextfieldUp;

@end

@protocol TextfieldViewControllerDelegate
- (void)textfieldViewControllerDidFinishHiding:(TextfieldViewController *)controller;
- (void)textfieldViewControllerDidGetToggled:(TextfieldViewController *)controller;
@end
