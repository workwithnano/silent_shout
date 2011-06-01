//
//  SettingsViewController.m
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 1/17/11.
//  Copyright 2011 Multi-Touchy-Feely. All rights reserved.
//

#import "SettingsViewController.h"
#import "Sound.h"

@implementation SettingsViewController

@synthesize settingName;
@synthesize scrollView;
@synthesize pageControl;
@synthesize settings;

#define DEGREES_TO_RADIANS(__ANGLE__) ((__ANGLE__) / 180.0 * M_PI)

static const CGFloat SLIDEIN_ANIMATION_DURATION = 0.31;
static const CGFloat PRELOAD_SCROLLVIEW_OFFSET_X = 500;
static const CGFloat PRELOAD_SCROLLVIEW_OFFSET_Y = -200;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
//- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
//    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
//    if (self) {
//    }
//    return self;
//}

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
  [super viewDidLoad];
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
  [super viewDidUnload];
	[scrollView release];
	[pageControl release];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)slideSettingsViewIn {
  
  //CGPoint originalCenter = scrollView.center;
  
  // Set up a multiplier so that we can delay certain slideins
  int multi = 1;
  if (self.settingName == @"texture") {
    multi = 1;
  }
  else if (self.settingName == @"lettering") {
    multi = 2;
  }
  else if (self.settingName == @"font") {
    multi = 3;
  }
  NSLog(@"Multiplier for setting '%@': %i", self.settingName, multi);
  
  // Move the frame out of view and then slide it in
  [UIView animateWithDuration:0.0
                   animations:^{
                     // First move the scrollview far away out of view of the user
                     CGPoint settingsCenter = scrollView.center;
                     NSLog(@"Previous center (x,y): (%1f,%1f)", settingsCenter.x, settingsCenter.y);
                     settingsCenter.x += (PRELOAD_SCROLLVIEW_OFFSET_X*multi);
                     settingsCenter.y += (PRELOAD_SCROLLVIEW_OFFSET_Y*multi);
                     NSLog(@"New center (x,y): (%1f,%1f)", settingsCenter.x, settingsCenter.y);
                     scrollView.center = settingsCenter;
                   }
                   completion:^(BOOL completed){
                     [UIView animateWithDuration:(SLIDEIN_ANIMATION_DURATION * multi)
                                      animations:^{
                                        // Then move the scrollview back into view of the user
                                        CGPoint settingsCenter = scrollView.center;
                                        NSLog(@"Previous center (x,y): (%1f,%1f)", settingsCenter.x, settingsCenter.y);
                                        settingsCenter.x -= (PRELOAD_SCROLLVIEW_OFFSET_X*multi);
                                        settingsCenter.y -= (PRELOAD_SCROLLVIEW_OFFSET_Y*multi);
                                        NSLog(@"New center (x,y): (%1f,%1f)", settingsCenter.x, settingsCenter.y);
                                        scrollView.center = settingsCenter;
                                      }
                                      completion:^(BOOL completed){
                                        
                                      }
                      ];
                   }
   ];
}

- (BOOL)addSettingArray:(NSArray*)settingArray {
  [settings addObject:settingArray];
  return YES;
}

- (void)slightlyRotateScrollViewAndPageControl:(UIView*)scrollObject :(UIPageControl*)pcObject {
  CGAffineTransform cgCTM = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(-14));
  scrollObject.transform = cgCTM;
  pcObject.transform = cgCTM;
  // viewObject.bounds = CGRectMake(0, 0, 480, 320);
}

- (IBAction)changeSettingsPage:(id)sender {
  
	/*
	 *	Change the scroll view
	 */
  CGRect frame = scrollView.frame;
  NSLog(@"Frame width: %f", frame.size.width);
  NSLog(@"Frame width * currentPage: %f", (frame.size.width * pageControl.currentPage));
  frame.origin.x = frame.size.width * pageControl.currentPage;
  frame.origin.y = 0;
	
  [scrollView scrollRectToVisible:frame animated:YES];
  
	/*
	 *	When the animated scrolling finishings, scrollViewDidEndDecelerating will turn this off
	 */
  pageControlIsChangingPage = YES;
}

- (void)setupSettingsPage {
  NSLog(@"setupSettingsPage has been called for '%@'", [self description]);
	scrollView.delegate = self;
  
	[scrollView setCanCancelContentTouches:NO];
	
	scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	scrollView.clipsToBounds = YES;
	scrollView.scrollEnabled = YES;
	scrollView.pagingEnabled = YES;
	
	CGFloat cx = 0;
  BOOL usingAnimation;
  UIImage *settingsImage;
  UIImageView *settingsImageView;  
  
  /* Load the various options from the settings array */
  NSEnumerator *enumerator = [settings objectEnumerator];
  id element;
  
  while ((element = [enumerator nextObject])) {
    // Check if the settings are using static images or animations
    if ([[element objectAtIndex:1] isKindOfClass:[NSMutableArray class]]) {
      NSLog(@"Using animation for setting '%@'", [element objectAtIndex:0]);
      usingAnimation = YES;
    }
    else {
      NSLog(@"Not using animation for setting '%@'", [element objectAtIndex:0]);
      usingAnimation = NO;
    }
    
    CGRect rect;
    // Set up images for CGRect determination
    if (usingAnimation) {
      NSLog(@"Object description of animation source image: %@", [[[element objectAtIndex:1] objectAtIndex:0] description]);
      settingsImage = [[element objectAtIndex:1] objectAtIndex:0];
      settingsImageView = [[UIImageView alloc] initWithImage:settingsImage];
      rect = settingsImageView.frame;
      // Set the animationImages to the array of images
      [settingsImageView setAnimationImages:[element objectAtIndex:1]];
      // How long does the animation last? So far all the animations are
      // 150 images at 30fps, so 5.0 seconds
      [settingsImageView setAnimationDuration:5.0];
      // repeat the animation forever
      [settingsImageView setAnimationRepeatCount:0];
      // start animating
      [settingsImageView startAnimating];
    }
    else {
      NSLog(@"Object description of non-animation source image: %@", [[element objectAtIndex:1] description]);
      settingsImage = [UIImage imageNamed:[element objectAtIndex:1]];
      settingsImageView = [[UIImageView alloc] initWithImage:settingsImage];
      rect = settingsImageView.frame;
    }
    rect.size.height = settingsImage.size.height;
    rect.size.width = settingsImage.size.width;
    rect.origin.x = ((scrollView.frame.size.width - settingsImage.size.width) / 2) + cx;
    rect.origin.y = ((scrollView.frame.size.height - settingsImage.size.height) / 2);
    
    settingsImageView.frame = rect;
    
    // Add the image view to the ScrollView
    [scrollView addSubview:settingsImageView];
    
    // Release the image view so that it can be remade with next image
    [settingsImageView release];
    
    cx += scrollView.frame.size.width;
  }
	
	self.pageControl.numberOfPages = [settings count];
	[scrollView setContentSize:CGSizeMake(cx, [scrollView bounds].size.height)];
  // No longer rotating!
  // [self slightlyRotateScrollViewAndPageControl:scrollView :pageControl];
  
  // Load default or saved font settings
  self.pageControl.currentPage = [[NSUserDefaults standardUserDefaults] integerForKey:[self settingName]];
  CGRect frame = scrollView.frame;
  frame.origin.x = frame.size.width * pageControl.currentPage;
  frame.origin.y = 0;
  [scrollView scrollRectToVisible:frame animated:YES];
  
  //[self slideSettingsViewIn];
}

#pragma mark -
#pragma mark UIScrollViewDelegate stuff
- (void)scrollViewDidScroll:(UIScrollView *)_scrollView
{
  if (pageControlIsChangingPage) {
    return;
  }
  
	/*
	 *	We switch page at 50% across
	 */
  CGFloat pageWidth = _scrollView.frame.size.width;
  int page = floor((_scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
  pageControl.currentPage = page;
  
	/*
	 *	Set the NSUserDefaults when the page changes
	 */
  NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
  [prefs setInteger:page forKey:settingName];
  [prefs synchronize];
  
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)_scrollView 
{
  pageControlIsChangingPage = NO;
  
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)_scrollView {
  
  // Play the "swish" sound effect
  // [Sound soundEffect:0];
}


- (void)dealloc {
  self.settings = nil;
  [super dealloc];
}


@end
