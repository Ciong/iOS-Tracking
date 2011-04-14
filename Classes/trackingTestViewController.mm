//
//  trackingTestViewController.m
//  trackingTest
//
//  Created by kronick on 1/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "trackingTestViewController.h"
#import "UIImage+cvConversions.h"

using namespace std;
using namespace cv;

@implementation trackingTestViewController

@synthesize captureSession, capturePreview, captureVideoOutput, previewView;
@synthesize pointTracker, objectFinder;
@synthesize glView, statusView;
@synthesize motionManager;

/*
// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}
*/


// Implement loadView to create a view hierarchy programmatically, without using a nib.
//- (void)loadView {
//}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
		NSLog(@"Loading view.");
	
	
	// Initialize member variables
	//mFernMatcher = cv::GenericDescriptorMatcher::create("FERN", "");
	GRID_X = 40;
	GRID_Y = 70;
	FASTThreshold = 30;
	frameCount = 0;
	setNewMilestone = NO;
	keyPointTarget = 200;
	
	self.objectFinder = [[[Homography alloc] init] autorelease];
	
	NSDate *d = [NSDate date];
	lastTime = [d timeIntervalSinceReferenceDate];
	
	self.pointTracker = [[[PointTracker alloc] init] autorelease];
	
	// Set up the capture session
	// ---------------------------------------------------------------
	self.captureSession = [[AVCaptureSession alloc] init];
	self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
	
	self.captureVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
	dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
	[self.captureVideoOutput setSampleBufferDelegate:self queue:queue];
	self.captureVideoOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
																		forKey:(id)kCVPixelBufferPixelFormatTypeKey];
	dispatch_release(queue);
	
	self.captureVideoOutput.minFrameDuration = CMTimeMake(1, 25);
	[NSTimer scheduledTimerWithTimeInterval:1/25. target:self selector:@selector(redrawKeyPoints:) userInfo:nil repeats:YES];
	
	AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
	
	[self.captureSession beginConfiguration];
	[self.captureSession addOutput:self.captureVideoOutput];
	[self.captureSession addInput:captureInput];
	[self.captureSession commitConfiguration];
	
	NSLog(@"Setting up preview layer...");
	// Set up the preview layer
	// ---------------------------------------------------------------
	CALayer *viewPreviewLayer = self.previewView.layer;
	self.capturePreview = [[[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession] autorelease];
	self.capturePreview.frame = self.previewView.bounds;
	self.capturePreview.videoGravity = AVLayerVideoGravityResize;
	[viewPreviewLayer addSublayer:self.capturePreview];
	
	// Set up the OpenGL view
	// ---------------------------------------------------------------
	NSLog(@"Setting up OpenGL rendering layer...");
	self.glView = [[GLView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[self.view insertSubview:self.glView atIndex:1];
	
	
	
	[self.captureSession startRunning];
	
	
	// Set up Core Motion services
	if(self.motionManager == nil) {
		self.motionManager = [[CMMotionManager alloc] init];
	}
	
	motionManager.deviceMotionUpdateInterval = 0.01;
	[motionManager startDeviceMotionUpdates];
	
	NSLog(@"View Did Load");
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	[self.captureSession release];
	[self.captureVideoOutput release];
}


- (void)dealloc {
    [super dealloc];
}

- (void)redrawKeyPoints:(NSTimer *)timer {
	//[self.overlayView setNeedsLayout];
	//[self.overlayView setNeedsDisplay];
}


# pragma -
# pragma mark AVCaptureVideoDataOutputSampleBufferDelegate


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
	IplImage *image = [Utilities IplImageFromSampleBuffer:sampleBuffer];
	
	//vector<cv::KeyPoint> keyPoints;
	cv::FAST(image, mDetectedKeyPoints, FASTThreshold, true);
	//NSLog(@"Keypoints found: %i, Threshold: %f", mDetectedKeyPoints.size(), FASTThreshold);
	// Dynamically adjust threshold 
	if(fabs(mDetectedKeyPoints.size() - keyPointTarget) > keyPointTarget  * .1) {
		FASTThreshold += (float)(mDetectedKeyPoints.size() - (float)keyPointTarget) * .01;
		if(FASTThreshold > 200) FASTThreshold = 200;
		if(FASTThreshold < 1)   FASTThreshold = 1;
	}
	//NSLog(@"Threshold: %f", FASTThreshold);
	//mCapturedImage.release();
	mCapturedImage = cv::Mat(image).clone();
	cvReleaseImage(&image);
	 
	//[self.overlayView setKeyPoints:mDetectedKeyPoints];
	[self.glView setKeyPoints:mDetectedKeyPoints];
	
	if(setNewMilestone && fabs(mDetectedKeyPoints.size() - keyPointTarget) < keyPointTarget * .1) {
		[self setMilestone];
		setNewMilestone = NO;
	}
	

	[self findReferenceImage];
	
	frameCount++;
	
	//[self redrawKeyPoints:nil];
	
	// Calculate frame rate
	NSDate *d = [NSDate date];
	double frameRate = 1 / ([d timeIntervalSinceReferenceDate] - lastTime);
	lastTime = [d timeIntervalSinceReferenceDate];
	NSLog(@"FPS: %f with %i keypoints", frameRate, mDetectedKeyPoints.size());
}


#pragma mark -
#pragma mark IBActions

- (IBAction) setReferenceImage {
	NSLog(@"Finding matches...");
	[self.statusView setHidden:NO];
	[self.statusView setBackgroundColor:[UIColor yellowColor]];
	
	[self setMilestone];
	vector<KeyPoint> sourceKeys = mDetectedKeyPoints;
	[objectFinder setSourceImage:&mMilestoneImage];
	[objectFinder setSourceKeyPoints:&mMilestoneKeyPoints];
	[objectFinder train];
	[objectFinder saveTrainingData:@"someshit.yaml.gz"];
	keyPointTarget = 300;
	[self.statusView setBackgroundColor:[UIColor greenColor]];
}
- (IBAction) loadReference {
	[self.statusView setHidden:NO];
	[self.statusView setBackgroundColor:[UIColor yellowColor]];
	[objectFinder loadTrainingData:@"someshit.yaml.gz"];
	[self.statusView setBackgroundColor:[UIColor greenColor]];
	keyPointTarget = 300;
}
- (IBAction) findReferenceImage {
	if([objectFinder isTrained]) {	// && [objectFinder sourceKeyPoints].size() > 0
		vector<KeyPoint> destKeys = mDetectedKeyPoints;
		[objectFinder setDestImage:&mCapturedImage];
		[objectFinder setDestKeyPoints:&destKeys];
		BOOL success = [objectFinder calculate];
		
		if(success) NSLog(@"Object detected!");
		else		NSLog(@"Object not detected.");
		
		Mat h = [objectFinder getMatrix];
		
		CGPoint corners[4];
		for(int i=0; i<4; i++) {
			double x,y;
			switch(i) {
				case 0:
					x=0; y=0; break;
				case 1:
					x=mCapturedImage.cols; y=0; break;
				case 2:
					x=mCapturedImage.cols; y=mCapturedImage.rows; break;
				case 3:
					x=0; y=mCapturedImage.rows; break;
					
			}
			Mat P = (Mat_<double>(3,1) << x, y, 1);
			//Mat P = (Mat_<double>(3,1) << x, y, 1);
			P = h * P;
			double W = P.at<double>(2,0);
			double X = P.at<double>(0,0) / W;
			double Y = P.at<double>(1,0) / W;
			
			corners[i] = success ? CGPointMake(X, Y) : CGPointMake(0, 0);
		}
		
		[self.glView setFoundCorners:corners];
		[self.glView setmodelviewMatrix:[objectFinder getModelviewMatrix]];
		[self.glView setDetected:success];
	}
	else {
		// Respond to CMDeviceMotion data
		CMRotationMatrix deviceR = motionManager.deviceMotion.attitude.rotationMatrix;
		cv::Mat rotationMatrix = (Mat_<float>(3,3) <<	deviceR.m11 , deviceR.m21, deviceR.m31,
														deviceR.m12 , deviceR.m22, deviceR.m32,
														deviceR.m13 , deviceR.m23, deviceR.m33);

		cv::Mat rotate90 = (Mat_<float>(3,3) << 0,1,0,
												1,0,0,
												0,0,1);
		
		cv::Mat flipX = (Mat_<float>(3,3) <<	-1,0,0,
												0,1,0,
												0,0,-1);
		
		rotationMatrix = rotationMatrix.t();
		rotationMatrix = flipX * rotationMatrix * flipX;
		rotationMatrix = rotate90 * rotationMatrix;
		rotationMatrix = rotationMatrix.t();
		
		cv::Mat deviceMatrix = (Mat_<float>(4,4) << rotationMatrix.at<float>(0,0) , rotationMatrix.at<float>(0,1) , rotationMatrix.at<float>(0,2) , 0,
													rotationMatrix.at<float>(1,0) , rotationMatrix.at<float>(1,1) , rotationMatrix.at<float>(1,2) , 0,
													rotationMatrix.at<float>(2,0) , rotationMatrix.at<float>(2,1) , rotationMatrix.at<float>(2,2) , 2,
													0 , 0 , 0 , 1);

		//deviceMatrix = deviceMatrix * flip_x;

		NSLog(@"Original");
		NSLog(@"%f\t%f\t%f\t%f", deviceMatrix.at<float>(0,0), deviceMatrix.at<float>(0,1), deviceMatrix.at<float>(0,2),  deviceMatrix.at<float>(0,3));
		NSLog(@"%f\t%f\t%f\t%f", deviceMatrix.at<float>(1,0), deviceMatrix.at<float>(1,1), deviceMatrix.at<float>(1,2),  deviceMatrix.at<float>(1,3));
		NSLog(@"%f\t%f\t%f\t%f", deviceMatrix.at<float>(2,0), deviceMatrix.at<float>(2,1), deviceMatrix.at<float>(2,2),  deviceMatrix.at<float>(2,3));
		NSLog(@"%f\t%f\t%f\t%f", deviceMatrix.at<float>(3,0), deviceMatrix.at<float>(3,1), deviceMatrix.at<float>(3,2),  deviceMatrix.at<float>(3,3));
		deviceMatrix = deviceMatrix.inv();
		
		[self.glView setmodelviewMatrix:deviceMatrix];
		[self.glView setDetected:YES];
		NSLog(@"Inverted:");
		NSLog(@"%f\t%f\t%f\t%f", deviceMatrix.at<float>(0,0), deviceMatrix.at<float>(0,1), deviceMatrix.at<float>(0,2),  deviceMatrix.at<float>(0,3));
		NSLog(@"%f\t%f\t%f\t%f", deviceMatrix.at<float>(1,0), deviceMatrix.at<float>(1,1), deviceMatrix.at<float>(1,2),  deviceMatrix.at<float>(1,3));
		NSLog(@"%f\t%f\t%f\t%f", deviceMatrix.at<float>(2,0), deviceMatrix.at<float>(2,1), deviceMatrix.at<float>(2,2),  deviceMatrix.at<float>(2,3));
		NSLog(@"%f\t%f\t%f\t%f", deviceMatrix.at<float>(3,0), deviceMatrix.at<float>(3,1), deviceMatrix.at<float>(3,2),  deviceMatrix.at<float>(3,3));
	}
}

- (IBAction) track {
	[NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(updateMatch:) userInfo:nil repeats:YES];
	
	setNewMilestone = YES;
}
- (void)updateMatch:(NSTimer*)theTimer {
	[self findReferenceImage];
}

- (void) setMilestone {
	mMilestoneImage = mCapturedImage.clone(); 
	mMilestoneKeyPoints = mDetectedKeyPoints;

}



@end
