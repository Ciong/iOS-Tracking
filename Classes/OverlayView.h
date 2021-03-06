//
//  OverlayView.h
//  trackingTest
//
//  Created by kronick on 1/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PointTracker.h"

@interface OverlayView : UIView {
	
@public
	std::vector<cv::KeyPoint> mDetectedKeyPoints;
	PointTracker *pointTracker;
	
	CGPoint foundCorners[4];
}

@property (nonatomic,retain) PointTracker *pointTracker;

- (void) setKeyPoints:(std::vector<cv::KeyPoint>) newKeyPoints;
- (CGPoint) getScreenCoord:(CGPoint)imgPoint;
- (void) setFoundCorners:(CGPoint[]) corners;
@end
