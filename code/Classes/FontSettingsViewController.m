//
//  FontSettingsViewController.m
//  Scrolling
//
//  Created by Neil Anderson on 9/7/10.
//  Copyright 2010 Nano LLC. All rights reserved.
//

#import "FontSettingsViewController.h"


@implementation FontSettingsViewController

#define DEGREES_TO_RADIANS(__ANGLE__) ((__ANGLE__) / 180.0 * M_PI)

static const CGFloat SLIDEIN_ANIMATION_DURATION = 0.5;
static const CGFloat PRELOAD_SCROLLVIEW_OFFSET_X = 500;
static const CGFloat PRELOAD_SCROLLVIEW_OFFSET_Y = -200;

- (void)setupFontPage
{
  
  NSLog(@"Setting up font settings");
  
  self.settingName = @"font";
  
  // Initialize the "font" option array
  self.settings = [[NSMutableArray alloc] init];
  
  // Declare the arrays for each sizing option
  [self addSettingArray:[NSArray arrayWithObjects:@"Pencil", @"icon-lettering_pencil", nil]];
  [self addSettingArray:[NSArray arrayWithObjects:@"Dry-Erase", @"icon-lettering_reddryerase", nil]];
  //[self addSettingArray:[NSArray arrayWithObjects:@"Marker", @"icon-lettering_marker", nil]];
  [self addSettingArray:[NSArray arrayWithObjects:@"Keyboard", @"icon-lettering_keyboard", nil]];
}

#pragma mark -
#pragma mark UIView boilerplate
- (void)viewDidLoad 
{
  [super viewDidLoad];
	[self setupFontPage];
  [self setupSettingsPage];
}


- (void)didReceiveMemoryWarning 
{
  [super didReceiveMemoryWarning];
}

- (void)viewDidUnload 
{
  
}


- (void)dealloc 
{
  [super dealloc];
}

#pragma mark -
#pragma mark The Guts

@end
