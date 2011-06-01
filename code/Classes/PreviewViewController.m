//
//  PreviewViewController.m
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 11/28/10.
//  Copyright 2010 Nano LLC. All rights reserved.
//

#import "PreviewViewController.h"
#import "Constants.h"


@implementation PreviewViewController

@synthesize previewBackground;
@synthesize userInputText;
@synthesize textView;
@synthesize textFont;
@synthesize outputLabel;

NSString *fontName;
NSUserDefaults *prefs;
int texture,font,sizing;

// Constants
static const CGFloat SCROLL_FONT_SIZE = 100;
static const CGFloat SCALE_MAX_FONT_SIZE = 200;


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
  [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}


- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

- (void)hideElements {
  
  /*
   Hide all text elements so that
   other functions can show only
   the desired element
   */
  
  outputLabel.hidden = YES;
  textView.hidden = YES;
}

-(void)setBackgroundColor:(UIColor *)color {
  self.view.backgroundColor = color;
}

-(void)setFont:(UIFont *)font {
  //self.view.backgroundColor = color;
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	// return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft);
  return NO;
}

-(void)setupPreviewWithOptions {
  
  NSLog(@"setupPreviewWithOptions");
  
  // Get the user defaults
  prefs = [NSUserDefaults standardUserDefaults];
  
  // Get font
  font = [prefs integerForKey:@"font"];
  fontName = [Constants getFontNameFromSavedFontNumber:font];
  
  // Get texture
  texture = [prefs integerForKey:@"texture"];
  switch (texture) {
    case 0:
      [previewBackground setImage:[UIImage imageNamed:@"bkgrd_texture-previewnotecard.jpg"]];
      break;
    case 1:
      [previewBackground setImage:[UIImage imageNamed:@"bkgrd_texture-previewwhiteboard.jpg"]];
      break;
    case 2:
      [previewBackground setImage:[UIImage imageNamed:@"bkgrd_texture-previewcardboard.jpg"]];
      break;
    case 3:
      [previewBackground setImage:[UIImage imageNamed:@"bkgrd_texture-previewpostcard"]];
      break;
  }
  
  // Get sizing
  sizing = [prefs integerForKey:@"lettering"];
  
}

- (void)fitWordsToScreen:(NSString *)userText  {
  
  // Hide other elements, show current element
  [self hideElements];
  outputLabel.hidden = NO;
  
  // Set the label text
  outputLabel.text = userText;
  
  /* This is where we define the ideal font that the Label wants to use.
   Use the font you want to use and the largest font size you want to use. */
  UIFont *fitWordsFont = [UIFont fontWithName:fontName size:28];
  
  NSLog(@"fontName declared in PreviewViewController: '%@'", fontName);
  
  int i;
  
  /* Time to calculate the needed font size.
   This for loop starts at the largest font size, and decreases by two point sizes (i=i-2)
   Until it either hits a size that will fit or hits the minimum size we want to allow (i > 10) */
  for(i = SCALE_MAX_FONT_SIZE; i > 10; i=i-2)
  {
    // Set the new font size.
    fitWordsFont = [fitWordsFont fontWithSize:i];
    // You can log the size you're trying: NSLog(@"Trying size: %u", i);
    
    /* This step is important: We make a constraint box 
	   using only the fixed WIDTH of the UILabel. The height will
	   be checked later. */ 
    CGSize constraintSize = CGSizeMake(300.0f, MAXFLOAT);
    
    // This step checks how tall the label would be with the desired font.
    CGSize labelSize = [self.outputLabel.text sizeWithFont:fitWordsFont constrainedToSize:constraintSize lineBreakMode:UILineBreakModeWordWrap];
    
    /* Here is where you use the height requirement!
	   Set the value in the if statement to the height of your UILabel
	   If the label fits into your required height, it will break the loop
	   and use that font size. */
    if(labelSize.height <= 206.0f)
      break;
  }
  // You can see what size the function is using by outputting: NSLog(@"Best size is: %u", i);
  
  // Set the UILabel's font to the newly adjusted font.
  outputLabel.textColor = [Constants getUIColorForFontName:fontName];
  outputLabel.font = fitWordsFont;
  
}

- (void)scrollWordsOnScreen:(BOOL)allowUserInteraction {
  
  // Hide other elements, show current element
  [self hideElements];
  textView.hidden = NO;
  
  // Get the user defaults
  NSUserDefaults *newprefs = [NSUserDefaults standardUserDefaults];
  int font = [newprefs integerForKey:@"font"];
  
  fontName = [Constants getFontNameFromSavedFontNumber:font];
  
  if (allowUserInteraction) {
    textView.userInteractionEnabled = YES;
  }
  else {
    textView.userInteractionEnabled = NO;
  }
  
  UIFont *scrollFont = [UIFont fontWithName:fontName size:SCROLL_FONT_SIZE];
  
  //textView.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"text"];
  textView.textColor = [UIColor blackColor];
  textView.font = scrollFont;
}

- (void)autoScrollWithText:(NSString *)userText {
  textView.text = userText;
  [self scrollWordsOnScreen:NO];
}

-(void)beginPreviewWithSizingMethod:(int)sizingNumber {
  switch (sizingNumber) {
    case 0:
      [self fitWordsToScreen:@""];
      break;
    case 1:
      [self scrollWordsOnScreen:NO];
      break;
    case 2:
      [self scrollWordsOnScreen:YES];
      break;
    default:
      [self fitWordsToScreen:@""];
      break;
  } 
}

- (void)viewWillAppear:(BOOL)animated {
  
  // Get the user defaults
  [self setupPreviewWithOptions];
  
}

- (void)viewDidLoad {
  
  [super viewDidLoad];
  
  [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
  
  outputLabel.text = @"";
  
}

- (void)dealloc {
  [super dealloc];
}

@end
