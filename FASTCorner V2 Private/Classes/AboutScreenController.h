/*****************************************************************************
 
 FAST Corner 2.0
 January 2011
 (c) Copyright 2011, Success Software Solutions
 See LICENSE.txt for license information.
 
 *****************************************************************************/

#import <UIKit/UIKit.h>


@interface AboutScreenController : UIViewController {
	NSString *urlString;
}

@property (nonatomic, retain) NSString *urlString;

- (IBAction) goToFASTWebsite:(id) sender;
- (IBAction) goToSuccessWebsite:(id) sender;
- (IBAction) goBack:(id) sender;

- (void)showLeaveAppMessage;

@end
