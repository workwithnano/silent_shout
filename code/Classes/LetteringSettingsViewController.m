//
//  LetteringSettingsViewController.m
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 1/22/11.
//  Copyright 2011 Multi-Touchy-Feely. All rights reserved.
//

#import "LetteringSettingsViewController.h"

/**
 Arrays which will hold the images for each lettering option animation
 */
NSMutableArray *scaleArray, *scrollArray, *swipeArray;

@implementation LetteringSettingsViewController


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
      
    }
    return self;
}

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

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
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)setupSettings {
  
  NSLog(@"Setting up lettering settings");
  
  self.settingName = @"lettering";
  
  // Initialize the "words" option array
  self.settings = [[NSMutableArray alloc] init];
  
  [self addSettingArray:[NSArray arrayWithObjects:@"Scale Message To Fit Screen", scaleArray, nil]];
  [self addSettingArray:[NSArray arrayWithObjects:@"Scroll Message Across Screen", scrollArray, nil]];
  //[self addSettingArray:[NSArray arrayWithObjects:@"Swipe Message", swipeArray, nil]];
  
}

- (void)setupLetteringAnimationArrays {
  
  scaleArray = [[NSMutableArray alloc] initWithCapacity:41];
  scrollArray = [[NSMutableArray alloc] initWithCapacity:41];
  //swipeArray = [[NSMutableArray alloc] initWithCapacity:41];
  
  // Loop through each of the images in the array. I know there are exactly
  // 150 for each one, but maybe I should make it find out the # of files…
  // TODO: Find out programmatically how many files there are in each
  // animation array
  int i;
  for(i = 0; i < 40; i++)
  {
    [scaleArray addObject:[UIImage imageNamed:[NSString stringWithFormat:@"scale_%05d", i]]];
    [scrollArray addObject:[UIImage imageNamed:[NSString stringWithFormat:@"Scroll-Your-Note_%05d", i]]];
    //[swipeArray addObject:[UIImage imageNamed:[NSString stringWithFormat:@"Swipe-Your-Note_%05d", i]]];
  }
  
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupLetteringAnimationArrays];
  [self setupSettings];
  [self setupSettingsPage];
}


- (void)dealloc {
    [super dealloc];
}


@end
