/*****************************************************************************
 
 FAST Corner 2.0
 January 2011
 (c) Copyright 2011, Success Software Solutions
 See LICENSE.txt for license information.
 
 *****************************************************************************/

#import <UIKit/UIKit.h>

@class AVCamViewController;

@interface FastCornerAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    AVCamViewController *viewController;
	UINavigationController *navigationController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet AVCamViewController *viewController;
@property (nonatomic, retain) UINavigationController *navigationController;

@end

