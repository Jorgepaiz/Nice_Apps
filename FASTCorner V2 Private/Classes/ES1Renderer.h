/*****************************************************************************
 
 FAST Corner 2.0
 January 2011
 (c) Copyright 2011, Success Software Solutions
 See LICENSE.txt for license information.
 
 *****************************************************************************/

#import "ESRenderer.h"
#import "AVCamViewDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>


@class MyVideoBuffer;

@interface ES1Renderer : NSObject <ESRenderer>
{
@private
    EAGLContext *context;

    // The pixel dimensions of the CAEAGLLayer
    GLint backingWidth;
    GLint backingHeight;

    // The OpenGL ES names for the framebuffer and renderbuffer used to render to this view
    GLuint defaultFramebuffer, colorRenderbuffer;
	
	AVCaptureSession *captureSession;
	MyVideoBuffer* videoTexture;
	id <AVCamViewDelegate> delegate;
}

@property (nonatomic, retain) AVCaptureSession *captureSession;
@property (nonatomic, assign) id <AVCamViewDelegate> delegate;

- (id) initWithSession: (AVCaptureSession*) session delegate: (id <AVCamViewDelegate>) _delegate;
- (void)render;
- (BOOL)resizeFromLayer:(CAEAGLLayer *)layer;

@end
