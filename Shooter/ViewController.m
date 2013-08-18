//
//  ViewController.m
//  Shooter
//
//  Created by Geppy Parziale on 2/24/12.
//  Copyright (c) 2012 iNVASIVECODE, Inc. All rights reserved.
//


/* sources that are relevant
 http://developer.apple.com/library/mac/documentation/AVFoundation/Reference/AVCaptureFileOutput_Class/Reference/Reference.html
 http://stackoverflow.com/questions/8786789/iphone-averrorinvalidvideocomposition-error-when-doing-image-overlay-on-video
 https://gist.github.com/stuffmc/1572592d
 http://www.slideshare.net/bobmccune/learning-avfoundation
 http://pastebin.com/3hQbr2rn
 http://stackoverflow.com/questions/3298290/avasset-and-avassettrack-track-management-in-ios-4-0
 http://developer.apple.com/library/ios/DOCUMENTATION/AudioVideo/Conceptual/AVFoundationPG/Articles/04_MediaCapture.html
 http://disanji.net/iOS_Doc/#documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/04_EditingAssets.html
 http://stackoverflow.com/questions/4710977/audio-will-make-avcapturesession-terminate
 
 
 show record progress
 limit record to 30 seconds
 show preview in new view controller
 display thumbnails on UIview
 select thumbnail
 
  
 
 */



#import "ViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>
@end



@implementation ViewController

@synthesize recordButton;
@synthesize outputURL;
@synthesize movieOutput;
@synthesize videoOutput;
@synthesize audioOutput;
@synthesize captureSession;
@synthesize audioDevice;
@synthesize videoDevice;
@synthesize videoDeviceInput;
@synthesize audioDeviceInput;
@synthesize previewLayer;
@synthesize videoWriter;
@synthesize videoWriterInput;
@synthesize audioWriterInput;
@synthesize isRecording;
@synthesize lastSampleTime;
@synthesize composition;
@synthesize videoComposition;
@synthesize assetArray;
@synthesize recordedTrackCount;
@synthesize rootLayer;
@synthesize isUsingFrontFacingCamera;
@synthesize progressBar;

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupCameraSession];
    progressBar.progress = 0.0;
    
}

- (void)setupCameraSession
{    
    ICLog;
    
    assetArray = [[NSMutableArray alloc] init];
    
    // Session
    captureSession = [AVCaptureSession new];
    
    
    [captureSession beginConfiguration];
    [captureSession setSessionPreset:AVCaptureSessionPresetMedium];
    
    
    // Capture device
    videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    NSError *error;
    
    // Device input
    audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
	if ( [captureSession canAddInput:videoDeviceInput] )
		[captureSession addInput:videoDeviceInput];
    
    videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
	if ( [captureSession canAddInput:audioDeviceInput] )
		[captureSession addInput:audioDeviceInput];
    
    //movieOutput = [[AVCaptureMovieFileOutput alloc] init];
    
    videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    videoOutput.alwaysDiscardsLateVideoFrames = NO;
    videoOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];

    audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    
    // Preview
	previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];    
    [previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    if(!rootLayer)
    {
        rootLayer = [[self view] layer];
        self.view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;

        rootLayer.bounds = CGRectMake(0, 0, self.view.layer.bounds.size.width, self.view.layer.bounds.size.height);
        [rootLayer setMasksToBounds:YES];
        [previewLayer setFrame:CGRectMake(0, 44, rootLayer.bounds.size.width, rootLayer.bounds.size.width)];
        [rootLayer insertSublayer:previewLayer atIndex:0];
    }
    
    [recordButton addTarget:self action:@selector(buttonDown:) forControlEvents:UIControlEventTouchDown];
    [recordButton addTarget:self action:@selector(buttonUp:) forControlEvents:UIControlEventTouchUpInside];
    
    dispatch_queue_t queue = dispatch_queue_create("MyQueue", NULL);
    [videoOutput setSampleBufferDelegate:self queue:queue];
    [audioOutput setSampleBufferDelegate:self queue:queue];
    dispatch_release(queue);
    

    [captureSession addOutput:videoOutput];
    [captureSession addOutput:audioOutput];
    
    composition = [AVMutableComposition composition];
    
    videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.frameDuration = CMTimeMake(1, 30);
    videoComposition.renderSize = CGSizeMake(480, 480);
    
    [captureSession commitConfiguration];
    [captureSession startRunning];
}

-(BOOL)setupWriter
{
    NSError *error = nil;
    NSString* assetName = [NSString stringWithFormat:@"%d",(int)[assetArray count]];
    NSURL* assetURL = [self createTempAssetFileURL:assetName];
    AVURLAsset* avAsset = [AVURLAsset assetWithURL:assetURL];
    
    //Add the asset to the class variable array
    [assetArray addObject:avAsset];
    recordedTrackCount.text = [NSString stringWithFormat:@"%d", (int)[assetArray count]];
    
    videoWriter = [[AVAssetWriter alloc] initWithURL:assetURL fileType:AVFileTypeQuickTimeMovie
                                               error:&error];
    if (error)
    {
        NSLog(@"%@: Error saving context: %@", [self class], [error localizedDescription]);
    }
    
    NSParameterAssert(videoWriter);
    
    // Add video input
    NSDictionary *videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithDouble:1024.0*1024.0], AVVideoAverageBitRateKey,
                                           nil ];
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:480], AVVideoWidthKey,
                                   [NSNumber numberWithInt:480], AVVideoHeightKey,
                                   videoCompressionProps, AVVideoCompressionPropertiesKey,
                                   nil];
    
    videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                            outputSettings:videoSettings];
    
    
    NSParameterAssert(videoWriterInput);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    
    
    // Add the audio input
    AudioChannelLayout acl;
    bzero( &acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    
    
    NSDictionary* audioOutputSettings = nil;
    // Both type of audio inputs causes output video file to be corrupted.
    if( NO ) {
        // should work from iphone 3GS on and from ipod 3rd generation
        audioOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                               [ NSNumber numberWithInt: kAudioFormatMPEG4AAC ], AVFormatIDKey,
                               [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                               [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
                               [ NSNumber numberWithInt: 64000 ], AVEncoderBitRateKey,
                               [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                               nil];
    } else {
        // should work on any device requires more space
        audioOutputSettings = [ NSDictionary dictionaryWithObjectsAndKeys:
                               [ NSNumber numberWithInt: kAudioFormatAppleLossless ], AVFormatIDKey,
                               [ NSNumber numberWithInt: 16 ], AVEncoderBitDepthHintKey,
                               [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
                               [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                               [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                               nil ];
    }
    
    audioWriterInput = [AVAssetWriterInput
                          assetWriterInputWithMediaType: AVMediaTypeAudio
                          outputSettings: audioOutputSettings] ;
    
    audioWriterInput.expectsMediaDataInRealTime = YES;
    
    
    
    // add input
    [videoWriter addInput:videoWriterInput];
    [videoWriter addInput:audioWriterInput];
    
    return YES;
}

-(void)buttonDown:(id)sender
{
    NSLog(@"button down");
    
    //NSURL *fileURL = [self tempFileURL];
    //[movieOutput startRecordingToOutputFileURL:fileURL recordingDelegate:self];
    
    if( !isRecording )
    {
        NSLog(@"start video recording...");
        if( ![self setupWriter] )
            return;
        
        isRecording = YES;
    }
    
}

-(void)buttonUp:(id)sender
{
    NSLog(@"BUTTON UP");
    
    if( isRecording )
    {
        isRecording = NO;
        
        [videoWriterInput markAsFinished];
        [videoWriter endSessionAtSourceTime:lastSampleTime];
        
        [videoWriter finishWritingWithCompletionHandler:^{
            
            //ADD the video URL asset to the composition
            NSLog(@"video recording successful");
            NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], AVURLAssetPreferPreciseDurationAndTimingKey, nil];
            AVAsset* sourceAsset = [AVURLAsset URLAssetWithURL:[videoWriter outputURL] options:options];
            CMTimeRange editRange = CMTimeRangeMake(CMTimeMake(0, 600), CMTimeMake(sourceAsset.duration.value, sourceAsset.duration.timescale));
            
            
            
            NSError* editError;
            // and add into your composition
            BOOL result = [composition insertTimeRange:editRange ofAsset:sourceAsset atTime:composition.duration error:&editError];
            if(result)
            {
                
            }
        }];
        
        NSLog(@"video recording stopped");
    }
    
}

-(void)saveVideoToDisk
{
    NSError *exportError = nil;
    
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:[composition copy] presetName:AVAssetExportPresetPassthrough];
    
    AVMutableVideoCompositionInstruction *videoCompositionInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    
    CMTime time = kCMTimeZero;
    for(int i=0; i<[assetArray count]; i++)
    {
        AVAsset *asset = [assetArray objectAtIndex:i];
        time = CMTimeAdd(time,asset.duration);
    }
    
    videoCompositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, time);
    videoComposition.instructions = [NSArray arrayWithObject:videoCompositionInstruction];
    
    outputURL = [self createTempAssetFileURL:@"export"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError* fileError;
    [fileManager removeItemAtPath:[outputURL path] error:&fileError];
    
    exportSession.outputURL = outputURL;
    exportSession.videoComposition = videoComposition;
    //exportSession.outputFileType = @"com.apple.quicktime-movie";
    exportSession.outputFileType=AVFileTypeQuickTimeMovie;
    
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        switch (exportSession.status) {
            case AVAssetExportSessionStatusFailed:{
                NSError *exportError = exportSession.error;
                
                NSLog (@"AVAssetExportSessionStatusFailed: %@", exportError);
                [self performSelectorOnMainThread:@selector (exportFailed:)
                                       withObject:nil
                                    waitUntilDone:NO];
                break;
            }
            case AVAssetExportSessionStatusCompleted: {
                NSLog (@"SUCCESS");
                [self performSelectorOnMainThread:@selector (saveExportToLibrary:)
                                       withObject:nil
                                    waitUntilDone:NO];
                break;
            }
        };
    }];
    
}

-(void) exportFailed:(id)sender
{
    NSLog(@"export failed");
    [self cleanUpLastSession];
}

-(void) saveExportToLibrary:(id)sender
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    [library writeVideoAtPathToSavedPhotosAlbum:outputURL
                                completionBlock:^(NSURL *assetURL, NSError *error) {
                                    if (error) {
                                        NSLog(@"%@: Error saving context: %@", [self class], [error localizedDescription]);
                                    }else{
                                        NSLog(@"SUCCESS!! file written to library!!");
                                    }
                                    [self resetCamera];
                                    [self viewDidAppear:NO];
                                }];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    //TODO: ensure that video length is capped at 30 seconds. The last record should truncate at th 
    /*
    if(composition.duration + captureOutput)
    {
        
    }
    */
    if( !CMSampleBufferDataIsReady(sampleBuffer) )
    {
        NSLog( @"sample buffer is not ready. Skipping sample" );
        return;
    }
    
    if(connection.supportsVideoOrientation)
    {
        [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }
    
    if( isRecording == YES )
    {
        lastSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        if( videoWriter.status != AVAssetWriterStatusWriting  )
        {
            [videoWriter startWriting];
            [videoWriter startSessionAtSourceTime:lastSampleTime];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"Buffer contains [DURATION:%.1fms] worth of audio", CMTimeGetSeconds(CMSampleBufferGetDuration(sampleBuffer)));
                float seconds = CMTimeGetSeconds(CMSampleBufferGetDuration(sampleBuffer));
                float actual = [progressBar progress];
                progressBar.progress = seconds / (float)30;
                NSLog(@"progress: %f", progressBar.progress);
            });
        }
        
        if( captureOutput == videoOutput )
        {
            [self newVideoSample:sampleBuffer];
        }
        else
        {
            [self newAudioSample:sampleBuffer];
        }
        
    }
}

-(void) newVideoSample:(CMSampleBufferRef)sampleBuffer
{
    if( isRecording )
    {
        if( videoWriter.status > AVAssetWriterStatusWriting )
        {
            NSLog(@"Warning: writer status is %d", videoWriter.status);
            if( videoWriter.status == AVAssetWriterStatusFailed )
            {
                NSLog(@"Error: %@", videoWriter.error);
            }
            return;
        }
        
        if( ![videoWriterInput appendSampleBuffer:sampleBuffer] )
        {
            NSLog(@"Unable to write to video input");
        }
        
    }
    
}

-(void)newAudioSample:(CMSampleBufferRef)sampleBuffer

{
    if( isRecording )
    {
        if( videoWriter.status > AVAssetWriterStatusWriting )
        {
            NSLog(@"Warning: writer status is %d", videoWriter.status);
            if( videoWriter.status == AVAssetWriterStatusFailed )
            {
                NSLog(@"Error: %@", videoWriter.error);
            }
            return;
        }
        
        if( ![audioWriterInput appendSampleBuffer:sampleBuffer] )
        {
            NSLog(@"Unable to write to audio input");
        }
        
    }
}

-(NSString*) formatAssetName:(NSString*)assetName
{
    return [NSString stringWithFormat:@"%@%@%@", @"temp_video_", assetName, @".mov"];
}

- (NSURL *) createTempAssetFileURL:(NSString*)assetName
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    //TODO: make this return a new iterative name and add it to a retained mutable array
    NSURL * assetURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(),
                                               [self formatAssetName:assetName]]];
    
    NSError* error;
    [fileManager removeItemAtURL:assetURL error:&error];
    return assetURL;
}

- (void)viewDidUnload
{
    [self setProgressBar:nil];
    [super viewDidUnload];
}

- (IBAction)doneButtonPressed:(id)sender
{
    [self saveVideoToDisk];
    
}

//TODO: press twice to actually delete
- (IBAction)deleteButtonPressed:(id)sender
{
    [self cleanUpLastSession];
}

- (void) removeLastAsset
{
    AVURLAsset* sourceAsset = (AVURLAsset *)[assetArray lastObject];
    CMTimeRange editRange = CMTimeRangeMake(CMTimeMake(0, 600), CMTimeMake(sourceAsset.duration.value, sourceAsset.duration.timescale));
    
    // and add into your composition
    [composition removeTimeRange:editRange];
}


//Call when you are ready to create a new offer
- (void) resetCamera
{
    [assetArray removeAllObjects];
    recordedTrackCount.text = @"0";
    [captureSession beginConfiguration];
        composition = [AVMutableComposition composition];
        
        videoComposition = [AVMutableVideoComposition videoComposition];
        videoComposition.frameDuration = CMTimeMake(1, 30);
        videoComposition.renderSize = CGSizeMake(480, 480);
    
    [captureSession commitConfiguration];
    
    
}

//Call when something goes wrong writing a video track
- (void) cleanUpLastSession
{
    [assetArray removeLastObject];
}

- (IBAction)swapCameraPressed:(id)sender
{
    AVCaptureDevicePosition desiredPosition;
    
    if (isUsingFrontFacingCamera)
    {
        desiredPosition = AVCaptureDevicePositionBack;
    }
    else
    {
        desiredPosition = AVCaptureDevicePositionFront;
    }
    
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
    {
        if ([d position] == desiredPosition)
        {
            [[previewLayer session] beginConfiguration];
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:d error:nil];
            for (AVCaptureInput *oldInput in [[previewLayer session] inputs])
            {
                [[previewLayer session] removeInput:oldInput];
            }
            [[previewLayer session] addInput:input];
            [[previewLayer session] commitConfiguration];
            break;
        }
    }
    
    isUsingFrontFacingCamera = !isUsingFrontFacingCamera;
}
@end
