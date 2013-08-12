//
//  ViewController.h
//  Shooter
//
//  Created by Geppy Parziale on 2/24/12.
//  Copyright (c) 2012 iNVASIVECODE, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CoreMedia.h>


@interface ViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>

@property (weak, nonatomic) IBOutlet UIButton *recordButton;
- (IBAction)doneButtonPressed:(id)sender;

- (IBAction)deleteButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (weak, nonatomic) IBOutlet UILabel *recordedTrackCount;

@property (retain, nonatomic) AVCaptureSession *captureSession;
@property (retain, nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (retain, nonatomic) AVCaptureDeviceInput *audioDeviceInput;
@property (retain, nonatomic) AVCaptureDevice *videoDevice;
@property (retain, nonatomic) AVCaptureDevice *audioDevice;
@property (retain, nonatomic) AVCaptureMovieFileOutput *movieOutput;
@property (retain, nonatomic) AVCaptureVideoDataOutput *videoOutput;
@property (retain, nonatomic) AVCaptureAudioDataOutput *audioOutput;
@property (retain, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (retain, nonatomic) AVAssetWriter *videoWriter;
@property (retain, nonatomic) AVAssetWriterInput *videoWriterInput;
@property (retain, nonatomic) AVAssetWriterInput *audioWriterInput;
@property (retain, nonatomic) AVMutableComposition *composition;
@property (retain, nonatomic) AVMutableVideoComposition *videoComposition;
@property (retain, nonatomic) NSMutableArray* assetArray;
@property (assign, nonatomic) BOOL isRecording;
@property (assign, nonatomic) CMTime lastSampleTime;
@property (retain, nonatomic) CALayer *rootLayer;
@property (assign, nonatomic) BOOL isUsingFrontFacingCamera;
- (IBAction)swapCameraPressed:(id)sender;


@property (retain, nonatomic) NSURL* outputURL;

@end
