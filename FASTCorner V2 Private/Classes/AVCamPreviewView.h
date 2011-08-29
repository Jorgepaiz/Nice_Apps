/*****************************************************************************
 
 FAST Corner 2.0
 January 2011
 (c) Copyright 2011, Success Software Solutions
 See LICENSE.txt for license information.
 
 *****************************************************************************/

#import <UIKit/UIKit.h>

@protocol AVCamPreviewViewDelegate
@optional
- (void)tapToFocus:(CGPoint)point;
- (void)tapToExpose:(CGPoint)point;
- (void)resetFocusAndExpose;
-(void)cycleGravity;
@end

@interface AVCamPreviewView : UIView {
    id <AVCamPreviewViewDelegate> _delegate;

}

@property (nonatomic,retain) IBOutlet id <AVCamPreviewViewDelegate> delegate;

@end
