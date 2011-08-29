/*****************************************************************************
 
 FAST Corner 2.0
 January 2011
 (c) Copyright 2011, Success Software Solutions
 See LICENSE.txt for license information.
 
 *****************************************************************************/

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import "AVCamViewDelegate.h"
#import "ESRenderer.h"


// This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView subclass.
// The view content is basically an EAGL surface you render your OpenGL scene into.
// Note that setting the view non-opaque will only work if the EAGL surface has an alpha channel.
@interface EAGLView : UIView
{    
@private
    id <ESRenderer> renderer;
	id <AVCamViewDelegate> delegate;

    BOOL animating;
    NSInteger animationFrameInterval;
    // Use of the CADisplayLink class is the preferred method for controlling your animation timing.
    // CADisplayLink will link to the main display and fire every vsync when added to a given run-loop.
    id displayLink;
}

@property (nonatomic, assign) 	id <AVCamViewDelegate> delegate;
@property (readonly, nonatomic, getter=isAnimating) BOOL animating;
@property (nonatomic) NSInteger animationFrameInterval;

- (id) initWithSession: (AVCaptureSession*) session delegate: (id <AVCamViewDelegate>) _delegate;
- (void)startAnimation;
- (void)stopAnimation;
- (void)drawView:(id)sender;

@end
