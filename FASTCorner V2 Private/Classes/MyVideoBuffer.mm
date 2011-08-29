/*****************************************************************************
 
 FAST Corner 2.0
 January 2011
 (c) Copyright 2011, Success Software Solutions
 See LICENSE.txt for license information.
 
 *****************************************************************************/

#import "MyVideoBuffer.h"
#import "AVCamViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <CoreGraphics/CoreGraphics.h>



@implementation MyVideoBuffer

@synthesize _session;
@synthesize delegate;
@synthesize previousTimestamp;
@synthesize videoFrameRate;
@synthesize videoDimensions;
@synthesize videoType;
@synthesize CameraTexture=m_textureHandle;
@synthesize corners;
@synthesize numCorners;


- (id) initWithSession: (AVCaptureSession*) session delegate:(id <AVCamViewDelegate>)_delegate
{
	if ((self = [super init]))
	{
		self._session = session;
		self.delegate = _delegate;
		
		[self._session beginConfiguration];
	
		//-- Create the output for the capture session.  We want 32bit BRGA
		AVCaptureVideoDataOutput * dataOutput = [[[AVCaptureVideoDataOutput alloc] init] autorelease];
		[dataOutput setAlwaysDiscardsLateVideoFrames:YES]; // Probably want to set this to NO when we're recording
		[dataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]]; // Necessary for manual preview
		dataOutput.minFrameDuration = CMTimeMake(1, 30);
		
		// we want our dispatch to be on the main thread so OpenGL can do things with the data
		[dataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
		
		[self._session addOutput:dataOutput];
		
		[self._session commitConfiguration];
		
		[self resetWithSize:640 Height:480];
	}
	return self;

}

-(GLuint)createVideoTextuerUsingWidth:(GLuint)w Height:(GLuint)h
{	
	GLuint handle;
	glGenTextures(1, &handle);
	glBindTexture(GL_TEXTURE_2D, handle);
	glTexParameterf(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glBindTexture(GL_TEXTURE_2D, 0);
	
	return handle;
}

- (void) resetWithSize:(GLuint)w Height:(GLuint)h
{
	NSLog(@"_session beginConfiguration");
	[_session beginConfiguration];
	
	//-- Match the wxh with a preset.
	if(w == 1280 && h == 720)
	{
		[_session setSessionPreset:AVCaptureSessionPreset1280x720];
	}
	else if(w == 640)
	{
		[_session setSessionPreset:AVCaptureSessionPreset640x480];
	}
	else if(w == 480)
	{
		[_session setSessionPreset:AVCaptureSessionPresetMedium];
	}
	else if(w == 192)
	{
		[_session setSessionPreset:AVCaptureSessionPresetLow];
	}
	
	[_session commitConfiguration];
	NSLog(@"_session commitConfiguration");
}


- (void) convertToBlackWhite:(unsigned char *)	pixels 
					   width:(int32_t)			width 
					  height:(int32_t)			height 
				  downSample:(int)				downSample
{	
	// Copy all memory to our buffer. It will be the source and destination for our calculations.
	// This improves performance significantly
	memcpy(bwImage,pixels,width*height*4);
	
	// Access the memory as an int to read 4 bytes at a time
	unsigned int * pntrBWImage= (unsigned int *)bwImage;
	unsigned int index = 0;
	unsigned int fourBytes;
	
	for (int j = 0; j < height / downSample; j++)
	{
		for (int i = 0; i < width / downSample; i++) 
		{
			index = width / downSample * j + i;
			fourBytes = pntrBWImage[j * downSample * width + i * downSample];
			bwImage[index] = ((unsigned char)fourBytes>>(2*8)) + ((unsigned char)fourBytes>>(1*8)) + ((unsigned char)fourBytes>>(0*8));
		}
	}
}

//The following is under the assumption that we are dealing with 
//a screen that is 1280 in width and 720 in height
//and that the origin is in top left corner
GLfloat spriteTexcoords[] = {
	0,0,
	0,1,
	1,0,
	1,1};

GLfloat spriteVertices[] =  {
	0,0,   
	0,720,   
	1280,0, 
	1280,720};

GLfloat transpose[]={
	0,1,0,0,
	1,0,0,0,
	0,0,1,0,
	0,0,0,1
};

EAGLContext *acontext;
GLuint arb,afb;
GLint abw;
GLint abh;

- (void) setGLStuff:(EAGLContext*)c :(GLuint)rb :(GLuint)fb :(GLuint)bw :(GLuint)bh 
{
	acontext=c;
	arb=rb;
	afb=fb;
	abw=bw;
	abh=bh;
}

GLuint createNPOTTexture(GLuint width,GLuint height) 
{
	GLuint handle;
	glGenTextures(1, &handle);
	glBindTexture(GL_TEXTURE_2D, handle);
	glTexParameterf(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_FALSE);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, 
				 GL_UNSIGNED_BYTE, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glBindTexture(GL_TEXTURE_2D, 0);
	
	return handle;
}

// Maximum corners drawn
#define MAX_CORNERS 50000

// Maximum neighbours searched in the array (X above, X below)
#define NEIGHBOURS_NEIGHBOURHOOD 30

// The threshold distance in pixel dimensions for 2 corners to be considered neighbours
#define NEIGHBOUR_THRESHOLD	320

// A buffer to hold corner information for OpenGL
static CGFloat cornersBuffer[2 * MAX_CORNERS];

// A buffer holding neighbour information for OpenGL
static CGFloat neighboursBuffer[4 * MAX_CORNERS * NEIGHBOURS_NEIGHBOURHOOD * 2];


// Calculate Euclidean distance from 2 points (without the sqrt)
- (int)distanceFrom:(xy)from to:(xy)to {
	return pow(to.x - from.x, 2.0) + pow(to.y - from.y, 2.0);
}


- (void) drawCorners {
	glVertexPointer(2, GL_FLOAT, 0, cornersBuffer);
	glEnableClientState(GL_VERTEX_ARRAY);
	glColor4f(0,1,0,1);  
	glPointSize(delegate.nonMaxSuppressionParam == NO ? 2 : 2);
	
	glDrawArrays(GL_POINTS, 0, numCorners < MAX_CORNERS ? numCorners : MAX_CORNERS);
	glColor4f(1, 1, 1, 1);
}


- (void) drawNearestNeighbours {
	int neighbours = 0;
	
	// For each corner
	for (int i = 0; i < numCorners; i++) {
		int myNearestNeighbour;
		int myNearestNeighbourDistance = 1000000;
		
		// Search my nearest neighbour
		for (int j = i - NEIGHBOURS_NEIGHBOURHOOD; j < i + NEIGHBOURS_NEIGHBOURHOOD; j++) {
			// skip self
			if (i == j) {
				continue;
			}
			
			// Skip out of bounds
			if (j < 0 || j >= numCorners) {
				continue;
			}
			
			// Check current neighbour
			if ([self distanceFrom:corners[i] to:corners[j]] < myNearestNeighbourDistance) {
				myNearestNeighbour = j;
				myNearestNeighbourDistance = [self distanceFrom:corners[i] to:corners[j]];
			}
		}
		
		if (myNearestNeighbourDistance <= NEIGHBOUR_THRESHOLD / pow(delegate.downSampleFactorParam,2)) {
			neighbours++;
			
			// Draw neighbour connection lines
			neighboursBuffer[neighbours*4+0] = (float)cornersBuffer[i*2];
			neighboursBuffer[neighbours*4+1] = (float)cornersBuffer[i*2+1];
			neighboursBuffer[neighbours*4+2] = (float)cornersBuffer[myNearestNeighbour*2];
			neighboursBuffer[neighbours*4+3] = (float)cornersBuffer[myNearestNeighbour*2+1];
		}
	}
	
	glVertexPointer(2, GL_FLOAT, 0, neighboursBuffer);
	glEnableClientState(GL_VERTEX_ARRAY);
	glColor4f(0,1,0,1);

	glDrawArrays(GL_LINES, 0, 2 * neighbours);
}

- (void) drawNeighbours {
	int neighbours = 0;
	
	// For each corner
	for (int i = 0; i < numCorners; i++) {
		
		// Search neighbours
		for (int j = i - NEIGHBOURS_NEIGHBOURHOOD; j < i + NEIGHBOURS_NEIGHBOURHOOD; j++) {
			// skip self
			if (i == j) {
				continue;
			}
			
			// Skip out of bounds
			if (j < 0 || j >= numCorners) {
				continue;
			}
			
			
			// Check current neighbour
			if ([self distanceFrom:corners[i] to:corners[j]] < NEIGHBOUR_THRESHOLD / pow(delegate.downSampleFactorParam,2)) {

				
				// Draw neighbour connection
				neighboursBuffer[neighbours*4+0] = (float)cornersBuffer[i*2];
				neighboursBuffer[neighbours*4+1] = (float)cornersBuffer[i*2+1];
				neighboursBuffer[neighbours*4+2] = (float)cornersBuffer[j*2];
				neighboursBuffer[neighbours*4+3] = (float)cornersBuffer[j*2+1];

				neighbours++;
			}
		}
	}
	
	glVertexPointer(2, GL_FLOAT, 0, neighboursBuffer);
	glEnableClientState(GL_VERTEX_ARRAY);
	glColor4f(0,1,0,1);
	glDrawArrays(GL_LINES, 0, 2 * neighbours);
	
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
	// Calculate FPS
	fpsAverageAgingFactor = 0.2;
	framesInSecond++;
	endTime = [[NSDate date] timeIntervalSince1970];
	
	if (startTime <= 0) {
		startTime = [[NSDate date] timeIntervalSince1970];
	}
	else {
		if (endTime - startTime >= 1) {
			double currentFPS = framesInSecond / (endTime - startTime);
			fpsAverage = fpsAverageAgingFactor * fpsAverage + (1.0 - fpsAverageAgingFactor) * currentFPS;
			startTime = [[NSDate date] timeIntervalSince1970];
			framesInSecond = 0;
		}
		
		delegate.fpsLabel.text = [NSString stringWithFormat:@"FPS = %.2f", fpsAverage];
	}

	// Get video specs
	CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
	self.videoDimensions = CMVideoFormatDescriptionGetDimensions(formatDesc);
	
	CMVideoCodecType type = CMFormatDescriptionGetMediaSubType(formatDesc);
#if defined(__LITTLE_ENDIAN__)
	type = OSSwapInt32(type);
#endif
	self.videoType = type;
	
	CGSize videoInViewDimensions = [AVCamViewController sizeForGravity:AVLayerVideoGravityResizeAspect
															 frameSize:CGSizeMake(videoDimensions.width, videoDimensions.height)
														  apertureSize:CGSizeMake(320, 480)];
	
	
	// Get the captured image
	CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
	
	// If we haven't created the video texture, do so now.
	if(m_textureHandle == 0)
	{
		m_textureHandle = createNPOTTexture(1280,720);
	}
	
	// Get the pointer to the picture data
	unsigned char* linebase = (unsigned char *)CVPixelBufferGetBaseAddress( pixelBuffer );
	
	// Draw the frame to the texture if Show Camera is on
	if (delegate.showCameraParam) {
		glBindTexture(GL_TEXTURE_2D, m_textureHandle);
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, videoDimensions.width, videoDimensions.height, GL_BGRA_EXT, GL_UNSIGNED_BYTE, linebase);
	}
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();

	// Set view port according to back or front camera
	if ([self.delegate usingBackFacingCamera]) {
		glOrthof(videoInViewDimensions.height, 0, videoInViewDimensions.width,0, 0, 1);
	}
	else {
		glOrthof(0, videoInViewDimensions.height, videoInViewDimensions.width,0, 0, 1);
	}

	
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glLoadMatrixf(transpose);
	
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glEnable(GL_TEXTURE_2D);
	
	glVertexPointer(2, GL_FLOAT, 0, spriteVertices);
	glTexCoordPointer(2, GL_FLOAT, 0, spriteTexcoords);	
	
	
	// Bind the texture if Show Camera is on
	if (delegate.showCameraParam) {
		glBindTexture(GL_TEXTURE_2D, m_textureHandle);
		glColor4f(1, 1, 1, 1);
	}
	else {
		glColor4f(0, 0, 0, 1);
	}

	glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	glDisable(GL_TEXTURE_2D);
	
	glDisableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);

	
	// Setup corners
	
	// Convert image to black and white (for FAST detection)
	[self convertToBlackWhite: linebase 
						width: videoDimensions.width 
					   height: videoDimensions.height 
				   downSample: delegate.downSampleFactorParam];
	
	// Process FAST Corner
	free(corners);
	
	if (delegate.nonMaxSuppressionParam == NO) {
		corners = fast9_detect(bwImage, 
							   videoDimensions.width	/ delegate.downSampleFactorParam,
							   videoDimensions.height / delegate.downSampleFactorParam, 
							   videoDimensions.width	/ delegate.downSampleFactorParam, 
							   delegate.thresholdParam,
							   &numCorners);
	}
	else {
		corners = fast9_detect_nonmax(bwImage, 
							   videoDimensions.width	/ delegate.downSampleFactorParam,
							   videoDimensions.height / delegate.downSampleFactorParam, 
							   videoDimensions.width	/ delegate.downSampleFactorParam, 
							   delegate.thresholdParam,
							   &numCorners);
	}

	
	delegate.countLabel.text = [NSString stringWithFormat:@"Points %d", numCorners];
	
	
	// Initialize drawing
	float frameWidth = videoInViewDimensions.width / delegate.downSampleFactorParam;
	float frameHeight = videoInViewDimensions.height / delegate.downSampleFactorParam;

	
	glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
	
	// Translate corners to our coordinates
	for (int i = 0; i < numCorners && i < MAX_CORNERS; i++) {
		// Corner coordinates
		cornersBuffer[2*i + 1]	= -(corners[i].x / frameWidth * 2.0 - 1.0);
		cornersBuffer[2*i]		= -(corners[i].y / frameHeight * 2.0 - 1.0);
		
		if (![self.delegate usingBackFacingCamera]) {
			cornersBuffer[2*i] *= -1;
		}
	}
	
	// Draw corners
	switch (delegate.displayMethodParam) {
		case DM_CORNERS:
			[self drawCorners];
			break;
		case DM_NEAREST:
			[self drawNearestNeighbours];
			break;
		case DM_NEIGHBOURS:
			[self drawNeighbours];
			break;
		default:
			break;
	}
	
	
	CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
	
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, arb);
	
	[acontext presentRenderbuffer:GL_RENDERBUFFER_OES];
}



-(void)renderCameraToSprite:(uint)text renderNothing:(BOOL)renderNothing
{
	float vW=videoDimensions.width;
	float vH=videoDimensions.height;
	float tW=1280;
	float tH=720;
	
	GLfloat spriteTexcoords[] = {
		vW/tW,vH/tH,   
		vW/tW,0.0f,
		0,vH/tH,   
		0.0f,0,};
	
	GLfloat spriteVertices[] =  {
		0,0,0,   
		320,0,0,   
		0,480,0, 
		320,480,0};
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrthof(0, 320, 0, 480, 0, 1);
	
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
	
	if (renderNothing) {
		return;
	}
		
	glDisable(GL_DEPTH_TEST);
	glDisableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_VERTEX_ARRAY);
	glVertexPointer(3, GL_FLOAT, 0, spriteVertices);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glTexCoordPointer(2, GL_FLOAT, 0, spriteTexcoords);	
	glBindTexture(GL_TEXTURE_2D, text);
	glEnable(GL_TEXTURE_2D);

	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

	glDisableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glBindTexture(GL_TEXTURE_2D, 0);
	glDisable(GL_TEXTURE_2D);
	glEnable(GL_DEPTH_TEST);
}


- (void)dealloc 
{
	[_session release];
	
	[super dealloc];
}

@end
