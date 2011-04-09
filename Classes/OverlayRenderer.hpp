/*
 *  OverlayRenderer.hpp
 *  trackingTest
 *
 *  Created by kronick on 4/6/11.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */
#include <opencv2/opencv.hpp>
#include <OpenGLES/ES1/gl.h>
#include <OpenGLES/ES1/glext.h>
#include <CoreGraphics/CGGeometry.h>

enum DeviceOrientation {
	DeviceOrientationUnknown,
	DeviceOrientationPortrait,
	DeviceOrientationPortraitUpsideDown,
	DeviceOrientationLandscapeLeft,
	DeviceOrientationLandscapeRight,
	DeviceOrientationFaceUp,
	DeviceOrientationFaceDown
};

struct vertex3 {
	float x, y, z;
};
struct vertex2 {
	float x, y;
};


class OverlayRenderer {
public:
	OverlayRenderer();
	void Initialize(int width, int height);
	void Render();
	void UpdateAnimation(float timeStep) {}
	void OnRotate(DeviceOrientation newOrientation) {}
	
	void DrawRect(float x, float y, float width, float height);
	void DrawLine(float x1, float y1, float x2, float y2);
	void DrawLine(float x1, float y1, float z1, float x2, float y2, float z2);
	
	void setKeypoints(std::vector<cv::KeyPoint> newKeypoints);
	void setCorners(CGPoint corners[]);
	void setModelviewMatrix(cv::Mat matrix);
	void setDrawOverlay(bool draw);
	
	int frameCount;
private:
	GLuint m_framebuffer;
	GLuint m_renderbuffer;
	
	std::vector<cv::KeyPoint> m_keypoints;
	
	CGPoint foundCorners[4];
	GLfloat m_modelviewMatrix[16];
	GLfloat m_modelviewMatrix_target[16];
	
	bool m_drawOverlay;
	
	int m_overlayFade;
	const static int OVERLAY_FADE_TIME = 30;
};