//
//  FlipsideViewController.m
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 8/23/10.
//  Copyright Nano LLC 2010. All rights reserved.
//

#import "FlipsideViewController.h"
#import "Constants.h"
#import <QuartzCore/QuartzCore.h>

#define UIColorFromRGB(rgbValue) [UIColor \
colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0xFF00) >> 8))/255.0 \
blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

#define RGB_INTENSITY(__NUMBER__) ((__NUMBER__) / 255.0)

#define DEGREES_TO_RADIANS(__ANGLE__) ((__ANGLE__) / 180.0 * M_PI)

@implementation FlipsideViewController

@synthesize delegate;
@synthesize userInputText;
@synthesize textView;
@synthesize outputLabel;
@synthesize toolbar;
@synthesize swipeView;
@synthesize outputWebView;
@synthesize bgImage;

NSString * fontName;
UIColor * fontColor;

NSString * backgroundName;

// Constants
static const CGFloat SCROLL_FONT_SIZE = 180;
static const int SCALE_MAX_FONT_SIZE = 360;

-(UIImage *)grabImageFromView: (UIView *) viewToGrab {
  
  UIGraphicsBeginImageContext(viewToGrab.bounds.size);
  
  [[viewToGrab layer] renderInContext:UIGraphicsGetCurrentContext()];
  UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return viewImage;
}

- (void)returnToStart:(BOOL)userWantsToGoBackToStart {
  
  // Make sure we get back to portrait if we were in landscape
  [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationPortrait animated:NO];
  
  [UIApplication sharedApplication].statusBarHidden = NO;
  [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleBlackOpaque;
  
  if (userWantsToGoBackToStart) {
    [self.delegate flipsideViewControllerDidFinish:self returnToStart:YES];
  }
  else {
    [self.delegate flipsideViewControllerDidFinish:self returnToStart:NO];
  }
  
}

- (IBAction)back:(id)sender {
  
  [self returnToStart:NO];
  
}

- (IBAction)doubleBack:(id)sender {
  
  [self returnToStart:YES];
  
}

//Add text to UIImage
-(UIImage *)addTextToImage:(UIImage *)img withText:(char *)txt withFont:(char *)fnt withFontSize:(int)fntSize {

  // Store image width and height in memory
  int bgW, bgH;
  bgW = img.size.width;
  bgH = img.size.height;
  
  // Set up colorspace and context for image we're about to create
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef ctx = CGBitmapContextCreate(NULL, bgW, bgH, 8, 4 * bgW, colorSpace, kCGImageAlphaPremultipliedFirst);
  
  CGContextDrawImage(ctx, CGRectMake(0, 0, bgW, bgH), img.CGImage);
  CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
	
  CGContextSelectFont(ctx, fnt, fntSize, kCGEncodingMacRoman);
  CGContextSetTextDrawingMode(ctx, kCGTextFill);
  CGContextSetRGBFillColor(ctx, RGB_INTENSITY(231.0), RGB_INTENSITY(255.0), RGB_INTENSITY(32.0), 1);
	
  CGContextShowTextAtPoint(ctx, 100, 100, txt, strlen(txt));
	
	
  CGImageRef imageMasked = CGBitmapContextCreateImage(ctx);
  CGContextRelease(ctx);
  CGColorSpaceRelease(colorSpace);
	
  return [UIImage imageWithCGImage:imageMasked];
  
}

- (void)hideElements {
  
  /*
   Hide all text elements so that
   other functions can show only
   the desired element
   */
  
  bgImage.hidden = YES;
  outputLabel.hidden = YES;
  textView.hidden = YES;
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
}

- (void)fitWordsToScreen {
  
  UIImage* backgroundImage = [UIImage imageNamed:backgroundName];
  
  // Store image width and height in memory
  int bgW, bgH;
  bgW = backgroundImage.size.width;
  bgH = backgroundImage.size.height;
  
  // Hide other elements, show current element
  [self hideElements];
  outputLabel.hidden = NO;
  bgImage.hidden = NO;
  
  // Set the label text
  outputLabel.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"text"];
  
  /* This is where we define the ideal font that the Label wants to use.
   Use the font you want to use and the largest font size you want to use. */
  UIFont *fitWordsFont = [UIFont fontWithName:fontName size:28];
  
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
    CGSize constraintSize = CGSizeMake(420.0f, MAXFLOAT);
    
    // This step checks how tall the label would be with the desired font.
    CGSize labelSize = [self.outputLabel.text sizeWithFont:fitWordsFont constrainedToSize:constraintSize lineBreakMode:UILineBreakModeWordWrap];
    
    /* Here is where you use the height requirement!
	   Set the value in the if statement to the height of your UILabel
	   If the label fits into your required height, it will break the loop
	   and use that font size. */
    if(labelSize.height <= 280.0f)
      break;
  }
  // You can see what size the function is using by outputting: NSLog(@"Best size is: %u", i);
  
  // Set the UILabel's font to the newly adjusted font.
  outputLabel.textColor = fontColor;
  // outputLabel.highlighted = YES;
  outputLabel.font = fitWordsFont;
  
  UIImage* labelImage = [self grabImageFromView:outputLabel];
  
  CGSize newSize = CGSizeMake(bgW, bgH);
  UIGraphicsBeginImageContext( newSize );
  
  // Use existing opacity as is
  [backgroundImage drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
  // Apply supplied opacity
  [labelImage drawInRect:CGRectMake(0,0,newSize.width,newSize.height) blendMode:kCGBlendModeMultiply alpha:1.0];
  
  UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
  
  UIGraphicsEndImageContext();
  
  outputLabel.hidden = YES;
  [[self bgImage] setImage:newImage];

}

- (void)scrollWordsOnScreen:(BOOL)allowUserInteraction {
  
  // Hide other elements, show current element
  [self hideElements];
  textView.hidden = NO;
  
  if (allowUserInteraction) {
    textView.userInteractionEnabled = YES;
  }
  else {
    textView.userInteractionEnabled = NO;
  }
  
  UIFont *scrollFont = [UIFont fontWithName:fontName size:SCROLL_FONT_SIZE];
  
  textView.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"text"];
  textView.textColor = fontColor;
  textView.alpha = 0.75f;
  textView.font = scrollFont;
  
  [[self bgImage] setImage:[UIImage imageNamed:backgroundName]];
  bgImage.hidden = NO;
  
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight);
}

- (void)didRotate:(NSNotification *)notification {
  
  UIDeviceOrientation orientation = [[notification object] orientation];
  
  if (orientation == UIDeviceOrientationPortrait) {
    [self returnToStart:NO];
  }
  else {
    
    [UIView beginAnimations:@"View rotate" context:nil];
    [UIView setAnimationDuration:0.35];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    
    if (orientation == UIDeviceOrientationLandscapeLeft) {
      [[UIApplication sharedApplication] setStatusBarOrientation:orientation animated:YES];
      [self.view setTransform:CGAffineTransformMakeRotation(M_PI / 2.0)];
    }
    else if (orientation == UIDeviceOrientationLandscapeRight) {
      [[UIApplication sharedApplication] setStatusBarOrientation:orientation animated:YES];
      [self.view setTransform:CGAffineTransformMakeRotation(M_PI / -2.0)];
    }
    
    [UIView commitAnimations];
    
  }
}

- (void) touchesEnded: (NSSet *) touches withEvent: (UIEvent *) event {
  if (toolbar.alpha == 0.0f)
    [UIView animateWithDuration:0.4f
                     animations:^{
                       toolbar.alpha = 1.0f;
                       CGRect scrollRect = textView.frame;
                       scrollRect.origin.y += 20;
                       textView.frame = scrollRect;
                       [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
                     }
                     completion:^(BOOL completed){
                       
                     }
     ];
  else
    [UIView animateWithDuration:0.4f
                     animations:^{
                       toolbar.alpha = 0.0f; 
                       CGRect scrollRect = textView.frame;
                       scrollRect.origin.y -= 20;
                       textView.frame = scrollRect;
                       [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
                     }
                     completion:^(BOOL completed){
                       
                     }
     ];
}

- (UIColor *)getUIColorForFontName:(NSString *)theFontName {
  
  if (theFontName == FONT_PAINTBRUSH)
    return UIColorFromRGB(0xA91515);
  else if (theFontName == FONT_HIGHLIGHTER)
    return UIColorFromRGB(0xE7FF20);
  else if (theFontName == FONT_MARKER)
    return UIColorFromRGB(0x272720);
  else if (theFontName == FONT_DRYERASE)
    return UIColorFromRGB(0xE93232);
  else {
    return UIColorFromRGB(0x000000);
  }

}

-(void) getLetteringInfo:(int)font {
  switch (font) {
    case 0:
      fontName = [Constants getFontNameFromSavedFontNumber:font];
      fontColor = [Constants getUIColorForFontName:fontName];
      break;
    case 1:
      fontName = [Constants getFontNameFromSavedFontNumber:font];
      fontColor = [Constants getUIColorForFontName:fontName];
      break;
    case 2:
      fontName = [Constants getFontNameFromSavedFontNumber:font];
      fontColor = [Constants getUIColorForFontName:fontName];
      break;
    case 3:
      fontName = [Constants getFontNameFromSavedFontNumber:font];
      fontColor = [Constants getUIColorForFontName:fontName];
      break;
    case 4:
      fontName = [Constants getFontNameFromSavedFontNumber:font];
      fontColor = [Constants getUIColorForFontName:fontName];
      break;
    default:
      fontName = [Constants getFontNameFromSavedFontNumber:font];
      fontColor = [Constants getUIColorForFontName:fontName];
      break;
  }
}

-(void) getBackgroundInfo:(int)background {

  switch (background) {
    case 0:
      backgroundName = @"bkgrd_texture-notecards.jpg";
      break;
    case 1:
      backgroundName = @"bkgrd_texture-whiteboard.jpg";
      break;
    case 2:
      backgroundName = @"bkgrd_texture-cardboard.jpg";
      break;
    case 3:
      backgroundName = @"bkgrd_texture-postcard";
      break;
  }  
}

// Public functions
- (void)autoScrollWithText:(NSString *)userText {
  textView.text = userText;
  [self scrollWordsOnScreen:NO];
}

- (void)viewWillAppear:(BOOL)animated {
  
//  [self.navigationController setNavigationBarHidden:YES];
  //[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
//  CGAffineTransform landscapeTransform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(-90));
//  landscapeTransform = CGAffineTransformTranslate( landscapeTransform, -90.0, -90.0 );
//  [self.view setTransform:landscapeTransform];
//  UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
//  if (orientation == UIDeviceOrientationLandscapeLeft) {
//    [[UIApplication sharedApplication] setStatusBarOrientation:orientation animated:NO];
//  }
//  else if (orientation == UIDeviceOrientationLandscapeRight) {
//    [[UIApplication sharedApplication] setStatusBarOrientation:orientation animated:NO];
//  }
}

- (void)viewDidLoad {
  
  [super viewDidLoad];
  
  [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didRotate:)
                                               name:UIDeviceOrientationDidChangeNotification
                                             object:nil];
  
  [UIApplication sharedApplication].statusBarHidden = YES;
  [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleBlackOpaque;
  [toolbar setFrame:CGRectMake(0, 0, 480, 38)];
  toolbar.alpha = 0.0f;
  //toolbar.autoresizingMask = toolbar.autoresizingMask | UIViewAutoresizingFlexibleHeight;
  
  // Get the user defaults
  NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
  
  // Which lettering should be used?
  int font = [prefs integerForKey:@"font"];
  [self getLetteringInfo:font]; 
  
  // Which texture should be used?
  int texture = [prefs integerForKey:@"texture"];
  [self getBackgroundInfo:texture];
  
  // Which type of sizing should be used?
  int sizing = [prefs integerForKey:@"lettering"];
  switch (sizing) {
    case 0:
      [self fitWordsToScreen];
      break;
    case 1:
      [self scrollWordsOnScreen:NO];
      break;
    case 2:
      [self scrollWordsOnScreen:YES];
      break;
    default:
      [self fitWordsToScreen];
      break;
  }
  
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
  
  [[UIApplication sharedApplication] setStatusBarOrientation:[UIDevice currentDevice].orientation animated:YES];
  
}

- (void)viewWillDisappear:(BOOL)animated {
  
  NSLog(@"viewWillDisappear called on FlipsideViewController");
  [self hideElements];
  
}

- (void)dealloc {
  //[textView dealloc];
  [super dealloc];
}


@end
