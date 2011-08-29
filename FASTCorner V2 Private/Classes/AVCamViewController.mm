/*****************************************************************************
 
 FAST Corner 2.0
 January 2011
 (c) Copyright 2011, Success Software Solutions
 See LICENSE.txt for license information.
 
 *****************************************************************************/


#import "AVCamViewController.h"
#import "AVCamCaptureManager.h"
#import "ExpandyButton.h"
#import "AVCamPreviewView.h"
#import <AVFoundation/AVFoundation.h>
#import "AboutScreenController.h"

// KVO contexts
static void *AVCamFocusModeObserverContext = &AVCamFocusModeObserverContext;
static void *AVCamTorchModeObserverContext = &AVCamTorchModeObserverContext;
static void *AVCamFlashModeObserverContext = &AVCamFlashModeObserverContext;
static void *AVCamAdjustingObserverContext = &AVCamAdjustingObserverContext;
static void *AVCamSessionPresetObserverContext = &AVCamSessionPresetObserverContext;
static void *AVCamFocusPointOfInterestObserverContext = &AVCamFocusPointOfInterestObserverContext;
static void *AVCamExposePointOfInterestObserverContext = &AVCamExposePointOfInterestObserverContext;

// HUD Appearance
const CGFloat hudCornerRadius = 8.f;
const CGFloat hudLayerWhite = 1.f;
const CGFloat hudLayerAlpha = .5f;
const CGFloat hudBorderWhite = .0f;
const CGFloat hudBorderAlpha = 1.f;
const CGFloat hudBorderWidth = 1.f;

@interface AVCamViewController ()
@property (nonatomic,retain) NSNumberFormatter *numberFormatter;
@property (nonatomic,assign,getter=isHudHidden) BOOL hudHidden;
@end

@interface AVCamViewController (InternalMethods)
- (CALayer *)createLayerBoxWithColor:(UIColor *)color;
- (void)updateExpandyButtonVisibility;
+ (CGRect)cleanApertureFromPorts:(NSArray *)ports;
+ (void)addAdjustingAnimationToLayer:(CALayer *)layer removeAnimation:(BOOL)remove;
- (CGPoint)translatePoint:(CGPoint)point fromGravity:(NSString *)gravity1 toGravity:(NSString *)gravity2;
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates;
@end


@interface AVCamViewController (AVCamCaptureManagerDelegate) <AVCamCaptureManagerDelegate>
@end

@interface AVCamViewController (AVCamPreviewViewDelegate) <AVCamPreviewViewDelegate>
@end

@implementation AVCamViewController

@synthesize openGLView;
@synthesize fpsLabel;
@synthesize countLabel;
@synthesize debugImageView;
@synthesize videoFrameWidth;
@synthesize videoFrameHeight;
@synthesize processingFrameWidth;
@synthesize processingFrameHeight;
@synthesize numberFormatter = _numberFormatter;
@synthesize captureManager = _captureManager;
@synthesize cameraToggleButton = _cameraToggleButton;
@synthesize recordButton = _recordButton;
@synthesize stillButton = _stillButton;
@synthesize infoButton = _infoButton;
@synthesize videoPreviewView = _videoPreviewView;
@synthesize captureVideoPreviewLayer = _captureVideoPreviewLayer;
@synthesize hudHidden = _hudHidden;
@synthesize downSampleFactor = _downSampleFactor;
@synthesize threshold = _threshold;
@synthesize nonMaxSuppression = _nonMaxSuppression;
@synthesize displayMethod = _displayMethod;
@synthesize showCamera = _showCamera;
@synthesize showInfo = _showInfo;
@synthesize focus = _focus;
@synthesize exposure = _exposure;
@synthesize whiteBalance = _whiteBalance;
@synthesize preset = _preset;
@synthesize statView = _statView;
@synthesize downSampleFactorParam;
@synthesize thresholdParam;
@synthesize nonMaxSuppressionParam;
@synthesize displayMethodParam;
@synthesize showCameraParam;
@dynamic usingBackFacingCamera;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:(NSCoder *)decoder];
    if (self != nil) {
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [numberFormatter setMinimumFractionDigits:2];
        [numberFormatter setMaximumFractionDigits:2];
        [self setNumberFormatter:numberFormatter];
        [numberFormatter release];            
        
    }
    return self;
}

- (void) dealloc
{
    [self setNumberFormatter:nil];
    [self setCaptureManager:nil];
    [super dealloc];
}

- (void)viewDidLoad {
    NSError *error;
    
	// Initialize parameters
	self.downSampleFactorParam	= 4;
	self.thresholdParam			= 20.0;
	self.nonMaxSuppressionParam	= NO;
	self.showCameraParam		= YES;
	self.displayMethod			= 0;
	
	AVCamCaptureManager *captureManager = [[AVCamCaptureManager alloc] init];
	
    if ([captureManager setupSessionWithPreset:AVCaptureSessionPreset640x480 error:&error]) {
        [self setCaptureManager:captureManager];
		
		// Get camera view properties
        UIView *view = [self videoPreviewView];
        CALayer *viewLayer = [view layer];
        [viewLayer setMasksToBounds:YES];
        CGRect bounds = [view bounds];
		
		// Create and openGL video preview view
		self.openGLView = [[[EAGLView alloc] initWithSession:[captureManager session] delegate:self] autorelease];
		openGLView.frame = bounds;
        
        [[captureManager session] startRunning];
        
        if ([[captureManager session] isRunning]) {                        
            [self setHudHidden:YES];
            
            [captureManager setOrientation:AVCaptureVideoOrientationPortrait];
            [captureManager setDelegate:self];

            NSUInteger cameraCount = [captureManager cameraCount];
            if (cameraCount < 1) {
                [[self cameraToggleButton] setEnabled:NO];
            } else if (cameraCount < 2) {
                [[self cameraToggleButton] setEnabled:NO]; 
            }
            
            
            [viewLayer insertSublayer:[openGLView layer] below:[[viewLayer sublayers] objectAtIndex:0]];

        } else {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Failure"
                                                                message:@"Failed to start session."
                                                               delegate:nil
                                                      cancelButtonTitle:@"Okay"
                                                      otherButtonTitles:nil];
            [alertView show];
            [alertView release];
            [[self stillButton] setEnabled:NO];
            [[self recordButton] setEnabled:NO];
            [[self cameraToggleButton] setEnabled:NO];
        }
    } else {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Input Device Init Failed"
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"Okay"
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];        
    }
    
    [captureManager release];
    
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload
{
    
    [self setVideoPreviewView:nil];
    [self setCaptureVideoPreviewLayer:nil];
    [self setCameraToggleButton:nil];
    [self setRecordButton:nil];
    [self setStillButton:nil];
    [self setInfoButton:nil];
    [self setPreset:nil];
}


+ (CGSize)sizeForGravity:(NSString *)gravity frameSize:(CGSize)frameSize apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;
    
    CGSize size;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }
    
    return size;
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([[change objectForKey:NSKeyValueChangeNewKey] isEqual:[NSNull null]]) {
        return;
    }
    if (AVCamFocusModeObserverContext == context) {
    } else if (AVCamFlashModeObserverContext == context) {
    } else if (AVCamTorchModeObserverContext == context) {
    } else if (AVCamAdjustingObserverContext == context) {
        UIView *view = nil;
        
        if (view != nil) {
            CALayer *layer = [view layer];
            [layer setBorderWidth:1.f];
            [layer setBorderColor:[[UIColor colorWithWhite:0.f alpha:.7f] CGColor]];
            [layer setCornerRadius:8.f];
            
            if ([[change objectForKey:NSKeyValueChangeNewKey] boolValue] == YES) {
                [layer setBackgroundColor:[[UIColor colorWithRed:1.f green:0.f blue:0.f alpha:.7f] CGColor]];
            } else {
                [layer setBackgroundColor:[[UIColor colorWithWhite:1.f alpha:.2f] CGColor]];
            }
        }        
    } else if (AVCamSessionPresetObserverContext == context) {        
        NSString *sessionPreset = [change objectForKey:NSKeyValueChangeNewKey];
        NSInteger selectedItem = -1;
        
        if ([[[self captureManager] sessionPreset] isEqualToString:sessionPreset]) {
            if ([sessionPreset isEqualToString:AVCaptureSessionPresetLow]) {
                selectedItem = 0;
            } else if ([sessionPreset isEqualToString:AVCaptureSessionPresetMedium]) {
                selectedItem = 1;
            } else if ([sessionPreset isEqualToString:AVCaptureSessionPresetHigh]) {
                selectedItem = 2;    
            } else if ([sessionPreset isEqualToString:AVCaptureSessionPresetPhoto]) {
                selectedItem = 3;
            } else if ([sessionPreset isEqualToString:AVCaptureSessionPreset640x480]) {
                selectedItem = 4;
            } else if ([sessionPreset isEqualToString:AVCaptureSessionPreset1280x720]) {
                selectedItem = 5;
            }
            
            [[self preset] setSelectedItem:selectedItem];            
        }
    } else if (AVCamFocusPointOfInterestObserverContext == context) {

    } else if (AVCamExposePointOfInterestObserverContext == context) {

    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Toolbar Actions
- (IBAction)hudViewToggle:(id)sender
{
    if ([self isHudHidden]) {
        [self setHudHidden:NO];
        
        [self updateExpandyButtonVisibility];
        
        [[self statView] setHidden:NO];
    } else {
        [self setHudHidden:YES];
        
        [self updateExpandyButtonVisibility];
        
        [[self statView] setHidden:YES];
    }    
}

- (IBAction)cameraToggle:(id)sender
{
    [[self captureManager] cameraToggle];
    [self updateExpandyButtonVisibility];
}

- (BOOL) usingBackFacingCamera {
	return [[[[self captureManager] videoInput] device] position] == AVCaptureDevicePositionBack;
}

- (IBAction)still:(id)sender
{
    [[self captureManager] captureStillImage];
    
    UIView *flashView = [[UIView alloc] initWithFrame:[[self videoPreviewView] frame]];
    [flashView setBackgroundColor:[UIColor whiteColor]];
    [flashView setAlpha:0.f];
    [[[self view] window] addSubview:flashView];
    
    [UIView animateWithDuration:.4f
                     animations:^{
                         [flashView setAlpha:1.f];
                         [flashView setAlpha:0.f];
                     }
                     completion:^(BOOL finished){
                         [flashView removeFromSuperview];
                         [flashView release];
                     }
     ];
}

- (IBAction) record:(id)sender {
//	QTMovie *movie;
}

- (IBAction)showAboutScreen:(id)sender {
	AboutScreenController *aboutScreenController = [[AboutScreenController alloc] initWithNibName:@"AboutScreen" bundle:nil];
	[self.navigationController pushViewController:aboutScreenController animated:YES];
	[aboutScreenController release];
}


#pragma mark HUD Actions
- (void)downSampleFactorChange:(id)sender
{
	switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
			self.downSampleFactorParam = 1;			
            break;
        case 1:
			self.downSampleFactorParam = 2;			
            break;
        case 2:
            self.downSampleFactorParam = 4;			
            break;
		case 3:
            self.downSampleFactorParam = 8;			
            break;
		case 4:
            self.downSampleFactorParam = 16;			
            break;
		case 5:
            self.downSampleFactorParam = 32;			
            break;
    }
}


- (void)thresholdChange:(id)sender
{
	switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
			self.thresholdParam = 5.0;
            break;
		case 1:
			self.thresholdParam = 10.0;
            break;
		case 2:
			self.thresholdParam = 20.0;
            break;
		case 3:
			self.thresholdParam = 40.0;
            break;
		case 4:
			self.thresholdParam = 80.0;
            break;
    }
}


- (void)nonMaxSuppressionChange:(id)sender
{
	switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
			self.nonMaxSuppressionParam = NO;
            break;
		case 1:
			self.nonMaxSuppressionParam = YES;
            break;
    }
}


- (void)showCameraChange:(id)sender
{
	switch ([(ExpandyButton *)sender selectedItem]) {
		case 0:
			showCameraParam = YES;
            break;
		case 1:
			showCameraParam = NO;
            break;			
	}
}


- (void)displayMethodChange:(id)sender
{
	switch ([(ExpandyButton *)sender selectedItem]) {
		case 0:
			displayMethodParam = DM_CORNERS;
            break;
		case 1:
			displayMethodParam = DM_NEAREST;
            break;
		case 2:
			displayMethodParam = DM_NEIGHBOURS;
            break;
	}
}


- (void)showInfoChange:(id)sender
{
	fpsLabel.hidden		= !fpsLabel.hidden;
	countLabel.hidden	= !countLabel.hidden;
}


- (void)focusChange:(id)sender
{
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setFocusMode:AVCaptureFocusModeLocked];
            break;
        case 1:
            [[self captureManager] setFocusMode:AVCaptureFocusModeAutoFocus];
            break;
        case 2:
            [[self captureManager] setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            break;
    }
}


- (void)exposureChange:(id)sender
{
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setExposureMode:AVCaptureExposureModeLocked];
            break;
        case 1:
            [[self captureManager] setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            break;
    }
}


- (void)whiteBalanceChange:(id)sender
{
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setWhiteBalanceMode:AVCaptureWhiteBalanceModeLocked];
            break;
        case 1:
            [[self captureManager] setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
            break;
    }
}


- (void)presetChange:(id)sender
{
    NSString *oldSessionPreset = [[self captureManager] sessionPreset];
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setSessionPreset:AVCaptureSessionPresetLow];
            break;
        case 1:
            [[self captureManager] setSessionPreset:AVCaptureSessionPresetMedium];
            break;
        case 2:
            [[self captureManager] setSessionPreset:AVCaptureSessionPresetHigh];
            break;
        case 3:
            [[self captureManager] setSessionPreset:AVCaptureSessionPreset640x480];
            break;
        case 4:
            [[self captureManager] setSessionPreset:AVCaptureSessionPreset1280x720];
            break;
    }
    
    if ([oldSessionPreset isEqualToString:[[self captureManager] sessionPreset]]) {
        if ([oldSessionPreset isEqualToString:AVCaptureSessionPresetLow]) {
            [(ExpandyButton *)sender setSelectedItem:0];
        } else if ([oldSessionPreset isEqualToString:AVCaptureSessionPresetMedium]) {
            [(ExpandyButton *)sender setSelectedItem:1];
        } else if ([oldSessionPreset isEqualToString:AVCaptureSessionPresetHigh]) {
            [(ExpandyButton *)sender setSelectedItem:2];
        } else if ([oldSessionPreset isEqualToString:AVCaptureSessionPresetPhoto]) {
            [(ExpandyButton *)sender setSelectedItem:3];
        } else if ([oldSessionPreset isEqualToString:AVCaptureSessionPreset640x480]) {
            [(ExpandyButton *)sender setSelectedItem:4];
        } else if ([oldSessionPreset isEqualToString:AVCaptureSessionPreset1280x720]) {
            [(ExpandyButton *)sender setSelectedItem:5];
        }
    }
}


@end

@implementation AVCamViewController (InternalMethods)

- (CALayer *)createLayerBoxWithColor:(UIColor *)color
{
    NSDictionary *unanimatedActions = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNull null], @"bounds",[NSNull null], @"frame",[NSNull null], @"position", nil];
    CALayer *box = [[CALayer alloc] init];
    [box setActions:unanimatedActions];
    [box setBorderWidth:3.f];
    [box setBorderColor:[color CGColor]];
    [box setOpacity:0.f];
    [unanimatedActions release];
    
    return [box autorelease];
}

- (void)updateExpandyButtonVisibility
{
    if ([self isHudHidden]) {
		[[self downSampleFactor]	setHidden:YES];
        [[self threshold]			setHidden:YES];
		[[self nonMaxSuppression]	setHidden:YES];
		[[self showCamera]			setHidden:YES];
		[[self displayMethod]		setHidden:YES];
		[[self showInfo]			setHidden:YES];
		[[self focus]				setHidden:YES];
        [[self exposure]			setHidden:YES];
        [[self whiteBalance]		setHidden:YES];
        [[self preset]				setHidden:YES];
    } else {
        NSInteger count = 0;
        UIView *view = [self videoPreviewView];
		AVCamCaptureManager *captureManager = [self captureManager];
        ExpandyButton *expandyButton;
        
		// Down sample button
		expandyButton = [self downSampleFactor];
		if (expandyButton == nil) {
			ExpandyButton *downSampleFactor =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f)
																   title:@"DownSp"
															 buttonNames:[NSArray arrayWithObjects:@"1", @"2", @"4", @"8", @"16", nil]
															selectedItem:1];
			[downSampleFactor addTarget:self action:@selector(downSampleFactorChange:) forControlEvents:UIControlEventValueChanged];
			[view addSubview:downSampleFactor];
			[self setDownSampleFactor:downSampleFactor];
			[downSampleFactor release];
		} else {
			CGRect frame = [expandyButton frame];
			[expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
			[expandyButton setHidden:NO];
		}
		count++;
		
		// Threshold button
		expandyButton = [self threshold];
		if (expandyButton == nil) {
			ExpandyButton *threshold =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
																			  title:@"Threshold"
																		buttonNames:[NSArray arrayWithObjects:@"5", @"10", @"20", @"40", @"80", nil]
																	   selectedItem:3];
			[threshold addTarget:self action:@selector(thresholdChange:) forControlEvents:UIControlEventValueChanged];
			[view addSubview:threshold];
			[self setThreshold:threshold];
			[threshold release];
		} else {
			CGRect frame = [expandyButton frame];
			[expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
			[expandyButton setHidden:NO];
		}
		count++;
		
		// Non max suppression button
		expandyButton = [self nonMaxSuppression];
		if (expandyButton == nil) {
			ExpandyButton *nonMaxSuppression =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
																	   title:@"Non Max"
																 buttonNames:[NSArray arrayWithObjects:@"Off", @"On", nil]
																selectedItem:0];
			[nonMaxSuppression addTarget:self action:@selector(nonMaxSuppressionChange:) forControlEvents:UIControlEventValueChanged];
			[view addSubview:nonMaxSuppression];
			[self setNonMaxSuppression:nonMaxSuppression];
			[nonMaxSuppression release];
		} else {
			CGRect frame = [expandyButton frame];
			[expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
			[expandyButton setHidden:NO];
		}
		count++;
		
		// Show camera button
		expandyButton = [self showCamera];
		if (expandyButton == nil) {
			ExpandyButton *showCamera =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
																		   title:@"Camera"
																	 buttonNames:[NSArray arrayWithObjects:@"On", @"Off", nil]
																	selectedItem:0];
			[showCamera addTarget:self action:@selector(showCameraChange:) forControlEvents:UIControlEventValueChanged];
			[view addSubview:showCamera];
			[self setShowCamera:showCamera];
			[showCamera release];
		} else {
			CGRect frame = [expandyButton frame];
			[expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
			[expandyButton setHidden:NO];
		}
		count++;
		
		// Display method button
		expandyButton = [self displayMethod];
		if (expandyButton == nil) {
			ExpandyButton *displayMethod =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
																		title:@"Display"
																  buttonNames:[NSArray arrayWithObjects:@"Corners", @"#1 Neigh.", @"All Neigh.", nil]
																 selectedItem:0
																  buttonWidth:70];
			[displayMethod addTarget:self action:@selector(displayMethodChange:) forControlEvents:UIControlEventValueChanged];
			[view addSubview:displayMethod];
			[self setDisplayMethod:displayMethod];
			[displayMethod release];
		} else {
			CGRect frame = [expandyButton frame];
			[expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
			[expandyButton setHidden:NO];
		}
		count++;

		// Show Info button
		expandyButton = [self showInfo];
		if (expandyButton == nil) {
			ExpandyButton *showInfo =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
																		title:@"Info"
																  buttonNames:[NSArray arrayWithObjects:@"On", @"Off", nil]
																 selectedItem:0];
			[showInfo addTarget:self action:@selector(showInfoChange:) forControlEvents:UIControlEventValueChanged];
			[view addSubview:showInfo];
			[self setShowInfo:showInfo];
			[showInfo release];
		} else {
			CGRect frame = [expandyButton frame];
			[expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
			[expandyButton setHidden:NO];
		}
		count++;
		
		// Focus mode button
		/*
		 
		 TODO - probably remove
		 
		 expandyButton = [self focus];
        if ([captureManager hasFocus]) {
            if (expandyButton == nil) {
                ExpandyButton *focus =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
                                                                       title:@"Focus"
                                                                 buttonNames:[NSArray arrayWithObjects:@"Lock",@"Auto",@"Cont",nil]
                                                                selectedItem:[captureManager focusMode]];
                [focus addTarget:self action:@selector(focusChange:) forControlEvents:UIControlEventValueChanged];
                [view addSubview:focus];
                [self setFocus:focus];
                [focus release];
            } else {
                CGRect frame = [expandyButton frame];
                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
                [expandyButton setHidden:NO];                
            }
            count++;
        } else {
            [expandyButton setHidden:YES];
        }
        
		// Exposure mode button
        expandyButton = [self exposure];
        if ([captureManager hasExposure]) {
            if (expandyButton == nil) {
                ExpandyButton *exposure =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
                                                                          title:@"AExp"
                                                                    buttonNames:[NSArray arrayWithObjects:@"Lock",@"Cont",nil]
                                                                   selectedItem:([captureManager exposureMode] == 2 ? 1 : [captureManager exposureMode])];
                [exposure addTarget:self action:@selector(exposureChange:) forControlEvents:UIControlEventValueChanged];
                [view addSubview:exposure];
                [self setExposure:exposure];
                [exposure release];
            } else {
                CGRect frame = [expandyButton frame];
                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
                [expandyButton setHidden:NO];                
            }
            count++;
        } else {
            [expandyButton setHidden:YES];
        }
        
		// White Balance mode button
        expandyButton = [self whiteBalance];
        if ([captureManager hasWhiteBalance]) {
            if (expandyButton == nil) {
                ExpandyButton *whiteBalance =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
                                                                              title:@"AWB"
                                                                        buttonNames:[NSArray arrayWithObjects:@"Lock",@"Cont",nil]
                                                                       selectedItem:([captureManager whiteBalanceMode] == 2 ? 1 : [captureManager whiteBalanceMode])];
                [whiteBalance addTarget:self action:@selector(whiteBalanceChange:) forControlEvents:UIControlEventValueChanged];
                [view addSubview:whiteBalance];
                [self setWhiteBalance:whiteBalance];
                [whiteBalance release];
            } else {
                CGRect frame = [expandyButton frame];
                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
                [expandyButton setHidden:NO];                
            }
            count++;
        } else {
            [expandyButton setHidden:YES];
        }
		 */
		
        // Video Preset button
		expandyButton = [self preset];
		if (expandyButton == nil) {
			ExpandyButton *preset =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
																	title:@"Preset"
															  buttonNames:[NSArray arrayWithObjects:@"Low",@"Med",@"High",@"480p",@"720p",nil]
															 selectedItem:3
															  buttonWidth:40.f];
			[preset addTarget:self action:@selector(presetChange:) forControlEvents:UIControlEventValueChanged];
			[view addSubview:preset];
			[self setPreset:preset];
			[preset release];
		} else {
			CGRect frame = [expandyButton frame];
			[expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
			[expandyButton setHidden:NO];                
		}
		count++;
                    
    }
}


+ (CGRect)cleanApertureFromPorts:(NSArray *)ports
{
    CGRect cleanAperture;
    for (AVCaptureInputPort *port in ports) {
        if ([port mediaType] == AVMediaTypeVideo) {
            cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
            break;
        }
    }
    return cleanAperture;
}

+ (void)addAdjustingAnimationToLayer:(CALayer *)layer removeAnimation:(BOOL)remove
{
    if (remove) {
        [layer removeAnimationForKey:@"animateOpacity"];
    }
    if ([layer animationForKey:@"animateOpacity"] == nil) {
        [layer setHidden:NO];
        CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        [opacityAnimation setDuration:.3f];
        [opacityAnimation setRepeatCount:1.f];
        [opacityAnimation setAutoreverses:YES];
        [opacityAnimation setFromValue:[NSNumber numberWithFloat:1.f]];
        [opacityAnimation setToValue:[NSNumber numberWithFloat:.0f]];
        [layer addAnimation:opacityAnimation forKey:@"animateOpacity"];
    }
}

- (CGPoint)translatePoint:(CGPoint)point fromGravity:(NSString *)oldGravity toGravity:(NSString *)newGravity
{
    CGPoint newPoint;
    
    CGSize frameSize = [[self videoPreviewView] frame].size;
    
    CGSize apertureSize = [AVCamViewController cleanApertureFromPorts:[[[self captureManager] videoInput] ports]].size;
    
    CGSize oldSize = [AVCamViewController sizeForGravity:oldGravity frameSize:frameSize apertureSize:apertureSize];
    
    CGSize newSize = [AVCamViewController sizeForGravity:newGravity frameSize:frameSize apertureSize:apertureSize];
    
    if (oldSize.height < newSize.height) {
        newPoint.y = ((point.y * newSize.height) / oldSize.height) - ((newSize.height - oldSize.height) / 2.f);
    } else if (oldSize.height > newSize.height) {
        newPoint.y = ((point.y * newSize.height) / oldSize.height) + ((oldSize.height - newSize.height) / 2.f) * (newSize.height / oldSize.height);
    } else if (oldSize.height == newSize.height) {
        newPoint.y = point.y;
    }
    
    if (oldSize.width < newSize.width) {
        newPoint.x = (((point.x - ((newSize.width - oldSize.width) / 2.f)) * newSize.width) / oldSize.width);
    } else if (oldSize.width > newSize.width) {
        newPoint.x = ((point.x * newSize.width) / oldSize.width) + ((oldSize.width - newSize.width) / 2.f);
    } else if (oldSize.width == newSize.width) {
        newPoint.x = point.x;
    }
    
    return newPoint;
}


- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates 
{
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = [[self videoPreviewView] frame].size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = [self captureVideoPreviewLayer];
    
    if ([[self captureVideoPreviewLayer] isMirrored]) {
        viewCoordinates.x = frameSize.width - viewCoordinates.x;
    }    
    
    if ( [[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize] ) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for (AVCaptureInputPort *port in [[[self captureManager] videoInput] ports]) {
            if ([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if ( [[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect] ) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if (point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if (point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if ([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}



@end

@implementation AVCamViewController (AVCamCaptureManagerDelegate)

- (void) captureStillImageFailedWithError:(NSError *)error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Still Image Capture Failure"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"Okay"
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];
}

- (void) cannotWriteToAssetLibrary
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Incompatible with Asset Library"
                                                        message:@"The captured file cannot be written to the asset library. It is likely an audio-only file."
                                                       delegate:nil
                                              cancelButtonTitle:@"Okay"
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];        
}

- (void) acquiringDeviceLockFailedWithError:(NSError *)error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Device Configuration Lock Failure"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"Okay"
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];    
}

- (void) assetLibraryError:(NSError *)error forURL:(NSURL *)assetURL
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Asset Library Error"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"Okay"
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];    
}

- (void) someOtherError:(NSError *)error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"Okay"
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];    
}

- (void) recordingBegan
{
    [[self recordButton] setTitle:@"Stop"];
    [[self recordButton] setEnabled:YES];
}

- (void) recordingFinished
{
    [[self recordButton] setTitle:@"Record"];
    [[self recordButton] setEnabled:YES];
}


@end
