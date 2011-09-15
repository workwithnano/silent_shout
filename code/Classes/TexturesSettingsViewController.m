//
//  TexturesSettingsViewController.m
//  Scrolling
//
//  Created by Neil Anderson on 9/7/10.
//  Copyright 2010 Nano LLC. All rights reserved.
//

#import "TexturesSettingsViewController.h"

@implementation TexturesSettingsViewController

#define DEGREES_TO_RADIANS(__ANGLE__) ((__ANGLE__) / 180.0 * M_PI)

static const CGFloat SLIDEIN_ANIMATION_DURATION = 0.5;
static const CGFloat PRELOAD_SCROLLVIEW_OFFSET_X = 500;
static const CGFloat PRELOAD_SCROLLVIEW_OFFSET_Y = -200;

- (void)setupTexturesPage
{
  
  NSLog(@"Setting up textures settings");
  
  self.settingName = @"texture";
  
  // Initialize the "font" option array
  self.settings = [[NSMutableArray alloc] init];
  
  // Declare the arrays for each sizing option
  [self addSettingArray:[NSArray arrayWithObjects:@"Notecard", @"icon-texture_notecard", nil]];
  [self addSettingArray:[NSArray arrayWithObjects:@"Postcard", @"icon-texture_whiteboard", nil]];
  // [self addSettingArray:[NSArray arrayWithObjects:@"Postcard", @"icon-texture_postcard", nil]];
  [self addSettingArray:[NSArray arrayWithObjects:@"Cardboard", @"icon-texture_cardboard", nil]];
  [self addSettingArray:[NSArray arrayWithObjects:@"Camera", @"icon-texture_camera", nil]];
  
}

- (void)addCameraButton
{
  
  // Remove the camera button's pageControl dot
  self.pageControl.numberOfPages = [[self settings] count] - 1;
  
  // Remove the camera from the totally draggable section
  [scrollView setContentSize:CGSizeMake((scrollView.frame.size.width * self.pageControl.numberOfPages),scrollView.frame.size.height)];
  
}

#pragma mark -
#pragma mark UIView boilerplate
- (void)viewDidLoad 
{
	[self setupTexturesPage];
  [self setupSettingsPage];
  [self addCameraButton];
  
  [super viewDidLoad];
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

@end