//
//  MainViewController.m
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 8/23/10.
//  Copyright Nano LLC 2010. All rights reserved.
//

#import "MainViewController.h"
#import "TexturesSettingsViewController.h"
#import "FontSettingsViewController.h"


@implementation MainViewController

@synthesize texturesViewController;
@synthesize letteringViewController;
@synthesize fontViewController;

@synthesize helpView;
@synthesize buttonsView;

@synthesize helpButton;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
  
	[super viewDidLoad];
  
  // List fontnames to get their correct names
  // NSLog(@"%@",[UIFont familyNames]);
  
  // Change background to anthony's texture
  self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"bkgrnd_main.jpg"]];
  
  // Change background of options bar
  // buttonsView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"toolbar_Buttons"]];
  
  // Change background of help overlay
  // helpView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"help_overlay"]];
}

- (void)editingViewControllerDidFinish:(EditingViewController *)controller {
  
  NSLog(@"editingViewControllerDidFinish:(EditingViewController *)controller just ran");
}

- (IBAction)showPreview:(id)sender {
  
  EditingViewController *controller = [[EditingViewController alloc] initWithNibName:@"PreviewView" bundle:nil];
	controller.delegate = self;
  
  [self.navigationController pushViewController:controller animated:YES];
  [controller release];

}

- (IBAction)toggleHelp:(id)sender {    
	
  // Toggle whether the help bubbles are shown.
	if (helpView.alpha == 0.0 || helpView.hidden) {
    [UIView animateWithDuration:0.5
                     animations:^{
                       // fade in the helpView
                       helpView.alpha = 1.0;
                     }
                     completion:^(BOOL completed){
                       
                     }
    ];
    helpButton.selected = YES;
  }
  else {
    [UIView animateWithDuration:0.5
                     animations:^{
                       // fade out the helpView
                       helpView.alpha = 0.0;
                     }
                     completion:^(BOOL completed){
                       
                     }
    ];
    helpButton.selected = NO;
  }
  
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  // Return YES for supported orientations.
  return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)dealloc {
    [super dealloc];
}


@end
