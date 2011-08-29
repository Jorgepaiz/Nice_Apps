/*****************************************************************************
 
 FAST Corner 2.0
 January 2011
 (c) Copyright 2011, Success Software Solutions
 See LICENSE.txt for license information.
 
 *****************************************************************************/

#import "AboutScreenController.h"


@implementation AboutScreenController

@synthesize urlString;

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
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (IBAction) goBack:(id) sender {
	[self.navigationController popViewControllerAnimated:YES];
}


- (IBAction) goToFASTWebsite:(id) sender {
	self.urlString = @"http://mi.eng.cam.ac.uk/~er258/work/fast.html";
	
	[self showLeaveAppMessage];
}


- (IBAction) goToSuccessWebsite:(id) sender {
	self.urlString = @"http://www.hatzlaha.co.il/150842/Labs";
	
	[self showLeaveAppMessage];
}

- (void)showLeaveAppMessage
{
	UIAlertView *alert = [[UIAlertView alloc] init];
	[alert setTitle:@"Leave Confirmation"];
	[alert setMessage:@"You will exit the app, and navigate to the website.\nContinue?"];
	[alert setDelegate:self];
	[alert addButtonWithTitle:@"No"];
	[alert addButtonWithTitle:@"Yes"];
	[alert show];
	[alert release];
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == 1)
	{
		// User chose to navigate to webpage
		NSString *url = [NSString stringWithString: urlString];
		[[UIApplication sharedApplication] openURL: [NSURL URLWithString: url]];		
	}
	else if (buttonIndex == 0)
	{
		// Do nothing
	}
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
	self.urlString = nil;
	
    [super dealloc];
}


@end
