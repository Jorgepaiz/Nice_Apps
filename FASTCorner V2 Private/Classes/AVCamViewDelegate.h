/*****************************************************************************
 
 FAST Corner 2.0
 January 2011
 (c) Copyright 2011, Success Software Solutions
 See LICENSE.txt for license information.
 
 *****************************************************************************/

#import <UIKit/UIKit.h>

// Display Method options
#define	DM_CORNERS		0
#define DM_NEAREST		1
#define DM_NEIGHBOURS	2

@protocol AVCamViewDelegate

@property (nonatomic) int	thresholdParam;
@property (nonatomic) BOOL	nonMaxSuppressionParam;
@property (nonatomic) int	downSampleFactorParam;
@property (nonatomic) BOOL	showCameraParam;
@property (nonatomic) int	displayMethodParam;
@property (nonatomic, readonly) BOOL		usingBackFacingCamera;
@property (nonatomic, retain) UILabel		*fpsLabel;
@property (nonatomic, retain) UILabel		*countLabel;
@property (nonatomic, retain) UIImageView	*debugImageView;

@end
