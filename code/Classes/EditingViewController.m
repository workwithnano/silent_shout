    //
//  EditingViewController.m
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 2/21/11.
//  Copyright 2011 Multi-Touchy-Feely. All rights reserved.
//

#import "EditingViewController.h"
#import "TextfieldViewController.h"
#import "FlipsideViewController.h"
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

@implementation EditingViewController

BOOL shouting;

@synthesize delegate;
@synthesize textViewController;

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
 */

- (void)setupEditingView {
  
  [textViewController viewWillAppear:NO];
  [textViewController setupTextfield];
  [textViewController moveTextfieldUp];
  textViewController.delegate = self;
  
  // Change background to anthony's texture
  self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"bkgrnd_main.jpg"]];
  
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
  
  [super viewDidLoad];
  
  [self setupEditingView];
  
  [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didRotate:)
                                               name:UIDeviceOrientationDidChangeNotification
                                             object:nil];
}

- (void)showInfo {
  
  if (shouting) {
    return;
  }
  else {
    shouting = YES;
  }

  FlipsideViewController *controller = [[FlipsideViewController alloc]
                                        initWithNibName:@"FlipsideView" bundle:nil];
	controller.delegate = self;
  controller.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
  
  // CATransition *transition = [CATransition animation];
  // transition.duration = 0.35;
  // transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
  
  // Transition type: move in from left
	// transition.type = kCATransitionMoveIn;
	// transition.subtype = kCATransitionFromLeft;
  
  // Transition type: fade in/out
  // transition.type = kCATransitionFade;
	
	// NSLog(@"%s: self.view.window=%@", __func__, self.view.window);
  // UIView *containerView = self.view.window;
  // [containerView.layer addAnimation:transition forKey:nil];
	
	[self presentModalViewController:controller animated:YES];
  
  // Make sure that the modal view is rotated
  // to the correct orientation depending on which
  // way the user rotates their device
  if ([UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeLeft) {
    NSLog(@"Shouting in LandscapeLeft Orientation");
    //[[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationLandscapeLeft animated:YES];
    [controller willRotateToInterfaceOrientation:UIDeviceOrientationLandscapeLeft duration:0.45];
  }
  else if ([UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeRight) {
    NSLog(@"Shouting in LandscapeRight Orientation");
    //[[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationLandscapeRight animated:YES];
    [controller willRotateToInterfaceOrientation:UIDeviceOrientationLandscapeRight duration:0.45];
  }
  else {
    NSLog(@"Shouting in LandscapeRight Orientation after clicking Done");
    [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationLandscapeRight animated:YES];
  }
  
	[controller release];
    
}


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orien*tations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)textfieldViewControllerDidFinishHiding:(TextfieldViewController *)controller {
  NSLog(@"Current visible UIViewController: %@", [[self navigationController] visibleViewController]);
  NSLog(@"Already shouting? %@",((shouting) ? @"YES" : @"NO"));
  NSLog(@"Shouting programatically");
  if ([[self navigationController] visibleViewController] != NULL)
    [self showInfo]; 
}

- (void)textfieldViewControllerDidGetToggled:(TextfieldViewController *)controller {
  NSLog(@"Hiding the damn preview controller");
  [self.navigationController popViewControllerAnimated:YES];
}

- (void)didRotate:(NSNotification *)notification {
  
  if (shouting)
    return;
  
  UIDeviceOrientation orientation = [[notification object] orientation];
  
  if (orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight) {
    if ([[self modalViewController] description] == (id)[NSNull null] || [[self modalViewController] description].length == 0) {
      [textViewController textFieldDidEndEditing:[textViewController mainTextField]];
    }
  }
  
}

- (void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller returnToStart:(BOOL)userWantsToGoBackToStart {
  
  shouting = NO;
  
  // CATransition *transition = [CATransition animation];
	// transition.duration = 0.35;
	// transition.timingFunction =
  // [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
  
  // Transition type: move in from left
	// transition.type = kCATransitionMoveIn;
	// transition.subtype = kCATransitionFromLeft;
  
  // Transition type: fade in/out
  // transition.type = kCATransitionFade;
	
	// NSLog(@"%s: controller.view.window=%@", __func__, controller.view.window);
	// UIView *containerView = controller.view.window;
	// [containerView.layer addAnimation:transition forKey:nil];
  
  // [[UIApplication sharedApplication] setStatusBarOrientation:UIDeviceOrientationPortrait animated:NO];
  
  if (userWantsToGoBackToStart) {
    [UIView animateWithDuration:0.4f
                     animations:^{
                       [self dismissModalViewControllerAnimated:YES];
                     }
                     completion:^(BOOL completed){
                       [self.navigationController popViewControllerAnimated:YES];
                     }
     ];
    
  }
  else {
    [self modalViewController].modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self dismissModalViewControllerAnimated:YES];
    [self setupEditingView];
  }
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewWillAppear:(BOOL)animated {
  if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
    NSLog(@"Editing interface was landscape, so here we go to change it back!");
    self.view.transform = CGAffineTransformIdentity;
    self.view.transform = CGAffineTransformMakeRotation(M_PI * (90) / 180.0);
    self.view.bounds = CGRectMake(0.0, 0.0, 480, 320);
  }
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end
