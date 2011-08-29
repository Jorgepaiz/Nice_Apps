/*****************************************************************************
 
 FAST Corner 2.0
 January 2011
 (c) Copyright 2011, Success Software Solutions
 See LICENSE.txt for license information.
 
 *****************************************************************************/

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "AVCamPreviewView.h"

enum {
    AVCamMirroringOff   = 1,
    AVCamMirroringOn    = 2,
    AVCamMirroringAuto  = 3
};
typedef NSInteger AVCamMirroringMode;

@protocol AVCamCaptureManagerDelegate
@optional
@property (nonatomic, retain) UILabel *fpsLabel;
@property (nonatomic, retain) UILabel *countLabel;
@property (nonatomic, retain) UIImageView *debugImageView;
- (void) captureStillImageFailedWithError:(NSError *)error;
- (void) acquiringDeviceLockFailedWithError:(NSError *)error;
- (void) cannotWriteToAssetLibrary;
- (void) assetLibraryError:(NSError *)error forURL:(NSURL *)assetURL;
- (void) someOtherError:(NSError *)error;
- (void) recordingBegan;
- (void) recordingFinished;
- (void) deviceCountChanged;
@end

@interface AVCamCaptureManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
@private
    // Capture Session
    AVCaptureSession *_session;
    AVCaptureVideoOrientation _orientation;
    AVCamMirroringMode _mirroringMode;
    
    // Devic Inputs
    AVCaptureDeviceInput *_videoInput;
    AVCaptureDeviceInput *_audioInput;
    
    // Capture Outputs
	AVCaptureVideoDataOutput *_movieCaptureOutput;
    AVCaptureMovieFileOutput *_movieFileOutput;
    AVCaptureStillImageOutput *_stillImageOutput;
    
    // Identifiers for connect/disconnect notifications
    id _deviceConnectedObserver;
    id _deviceDisconnectedObserver;
    
    // Identifier for background completion of recording
    UIBackgroundTaskIdentifier _backgroundRecordingID; 
    
    // Capture Manager delegate
    id <AVCamCaptureManagerDelegate> _delegate;
}

@property (nonatomic,readonly,retain) AVCaptureSession *session;
@property (nonatomic,assign) AVCaptureVideoOrientation orientation;
@property (nonatomic,readonly,retain) AVCaptureAudioChannel *audioChannel;
@property (nonatomic,assign) NSString *sessionPreset;
@property (nonatomic,assign) AVCamMirroringMode mirroringMode;
@property (nonatomic,readonly,retain) AVCaptureDeviceInput *videoInput;
@property (nonatomic,readonly,retain) AVCaptureDeviceInput *audioInput;
@property (nonatomic,assign) AVCaptureFlashMode flashMode;
@property (nonatomic,assign) AVCaptureTorchMode torchMode;
@property (nonatomic,assign) AVCaptureFocusMode focusMode;
@property (nonatomic,assign) AVCaptureExposureMode exposureMode;
@property (nonatomic,assign) AVCaptureWhiteBalanceMode whiteBalanceMode;
@property (nonatomic,readonly,retain) AVCaptureVideoDataOutput *movieCaptureOutput;
@property (nonatomic,readonly,retain) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic,assign) id <AVCamCaptureManagerDelegate> delegate;
@property (nonatomic,readonly,getter=isRecording) BOOL recording;

- (BOOL) setupSessionWithPreset:(NSString *)sessionPreset error:(NSError **)error;
- (BOOL) cameraToggle;
- (NSUInteger) cameraCount;
- (BOOL) hasFocus;
- (BOOL) hasExposure;
- (BOOL) hasWhiteBalance;
- (void) captureStillImage;
+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;

@end
