//
//  TextfieldViewController.m
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 9/20/10.
//  Copyright 2010 Nano LLC. All rights reserved.
//

#import "TextfieldViewController.h"
#import "PreviewViewController.h"


@implementation TextfieldViewController

@synthesize delegate;
@synthesize mainTextField;
@synthesize keyboardButton;
@synthesize textfieldButton;
@synthesize previewViewController;

static const CGFloat KEYBOARD_ANIMATED_DISTANCE = 255;
static const CGFloat PREVIEW_ANIMATED_DISTANCE = 228;
BOOL flipScreen = YES;
BOOL isAnimating = NO;
BOOL timerIsActivated = NO;
static const CGFloat SLIDING_ANIMATION_DURATION = 0.31;
static const CGFloat KEYBOARD_DOWN_ANIMATION_DURATION = 0.26;
static const CGFloat MINIMUM_SCROLL_FRACTION = 0.2;
static const CGFloat MAXIMUM_SCROLL_FRACTION = 0.8;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
  
  [self setupTextfield];
  [super viewDidLoad];
  
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

// Changes the preview background to selected texture
- (void)setPreviewBackground {
  
  // Set the font/background now
  NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
  int texture = [prefs integerForKey:@"texture"];
  switch (texture) {
    case 0:
      //[previewViewController setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"bkgrd_texture-previewcardboard.jpg"]]];
      break;
    case 1:
      //[previewViewController setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"bkgrd_texture-previewnotecard.jpg"]]];
      break;
    case 2:
      //[previewViewController setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"bkgrd_texture-previewpostcard"]]];
      break;
  }
}

#pragma mark -
#pragma mark The Guts
- (void)setupTextfield
{
	mainTextField.delegate = self;
  
  // Change background of textfield bar
  self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"toolbar_Textfield"]];
  
  // Set the background of the preview window
  [self setPreviewBackground];
  
  mainTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
  
  mainTextField.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"text"];
  
  [previewViewController fitWordsToScreen:mainTextField.text];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [textField resignFirstResponder];
  return NO;
}

- (IBAction)beginEditingMode:(id)sender {
  [self moveTextfieldUp];
}

- (IBAction)toggleTextfieldEditor:(id)sender {
  flipScreen = NO;
  //[self textFieldDidEndEditing:mainTextField];
  //[self textFieldShouldReturn:mainTextField];
  [self.delegate textfieldViewControllerDidGetToggled:self];
}

- (IBAction)textfieldUpdated:(id)sender {
  NSLog(@"UILabel Value Changing");
  [previewViewController fitWordsToScreen:mainTextField.text];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
  // Things that need to be done when the textfield is activated
  // [keyboardButton addTarget:self action:@selector(textFieldShouldReturn:) forControlEvents:UIControlEventTouchUpInside];
}

// Moves the textfield bar up to top of keyboard
- (void)moveTextfieldUp {
  
  [mainTextField becomeFirstResponder];
  
}

// Moves the textfield bar down to bottom of window
- (void)moveTextfieldDown {
  
  if (flipScreen) {
    [self.delegate textfieldViewControllerDidFinishHiding:self];
  }
  else {
    flipScreen = YES;
    //[self.delegate textfieldViewControllerDidGetToggled:self];
  }
 
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewWillAppear:(BOOL)animated {
  
  // Make sure that the setupPreviewOptions fires in the preview controller
  [previewViewController setupPreviewWithOptions];
  
}

- (void)viewDidUnload {
  [super viewDidUnload];
  [mainTextField resignFirstResponder];
  [mainTextField release];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  
  textfieldButton.hidden = NO;
    
  /*
  *	Save the text to the pref file
  */
  NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
  [prefs setObject:mainTextField.text forKey:@"text"];
  [prefs synchronize];
  
  [self moveTextfieldDown];
  
}


- (void)dealloc {
  [super dealloc];
}


@end
