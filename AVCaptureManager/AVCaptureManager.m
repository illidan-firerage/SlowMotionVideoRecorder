//
//  AVCaptureManager.m
//  SlowMotionVideoRecorder
//  https://github.com/shu223/SlowMotionVideoRecorder
//
//  Created by shuichi on 12/17/13.
//  Copyright (c) 2013 Shuichi Tsutsumi. All rights reserved.
//

#import "AVCaptureManager.h"
#import <AVFoundation/AVFoundation.h>


@interface AVCaptureManager () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic, readwrite) BOOL isRecording;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *assetVideoWriterInput;
@property (nonatomic, strong) AVAssetWriterInput *assetAudioWriterInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@end


@implementation AVCaptureManager

- (id)initWithPreviewView:(UIView *)previewView {
    
    self = [super init];
    
    if (self) {
        
        NSError *error = nil;
        
        self.captureSession = [[AVCaptureSession alloc] init];
        [self.captureSession beginConfiguration];
        [self.captureSession setSessionPreset:AVCaptureSessionPreset352x288];
        [self initVideoAudioWriter];
        
        AVCaptureDevice * videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        AVCaptureDevice * audioDevice1 = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice1 error:&error];
        
        self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [self.videoOutput setAlwaysDiscardsLateVideoFrames:YES];
        [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        [self.videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
        
        self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
        [self.audioOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
        
        [self.captureSession addInput:videoInput];
        [self.captureSession addInput:audioInput];
        [self.captureSession addOutput:self.videoOutput];
        [self.captureSession addOutput:self.audioOutput];
        
        [self.captureSession commitConfiguration];
        
        AVCaptureConnection *videoConnection = nil;
        for ( AVCaptureConnection *connection in [self.videoOutput connections] )
        {
            NSLog(@"%@", connection);
            for ( AVCaptureInputPort *port in [connection inputPorts] )
            {
                NSLog(@"%@", port);
                if ( [[port mediaType] isEqual:AVMediaTypeVideo] )
                {
                    videoConnection = connection;
                }
            }
        }
        if([videoConnection isVideoOrientationSupported]) // **Here it is, its always false**
        {
            [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
        }
        
        self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        self.previewLayer.frame = previewView.bounds;
        self.previewLayer.contentsGravity = kCAGravityResizeAspectFill;
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [previewView.layer insertSublayer:self.previewLayer atIndex:0];
        
        [self.captureSession startRunning];
        
    }
    return self;
}

#pragma mark -
#pragma mark - Private

-(void) initVideoAudioWriter

{
    CGSize size = CGSizeMake(320, (320. * 352.) / 288.);
    NSString *betaCompressionDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.mp4"];
    NSError *error = nil;
    unlink([betaCompressionDirectory UTF8String]);
    
    self.assetWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:betaCompressionDirectory]
                                                 fileType:AVFileTypeQuickTimeMovie
                                                    error:&error];
    
    NSParameterAssert(self.assetWriter);
    
    NSLog(@"error = %@", [error localizedDescription]);
    
//    NSDictionary *videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
//                                           [NSNumber numberWithDouble:128.0*1024.0], AVVideoAverageBitRateKey,
//                                           nil ];
    
    NSDictionary *videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:300.0*1024.0],
                                           AVVideoAverageBitRateKey ,AVVideoProfileLevelH264High40 /* Or whatever profile & level you wish to use */, AVVideoProfileLevelKey,
                                           [NSNumber numberWithInt: 3], AVVideoMaxKeyFrameIntervalKey,nil];
    
    
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:size.height], AVVideoHeightKey,videoCompressionProps, AVVideoCompressionPropertiesKey, nil];
    
    self.assetVideoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    NSParameterAssert(self.assetVideoWriterInput);
    self.assetVideoWriterInput.expectsMediaDataInRealTime = YES;
    
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    
    self.pixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.assetVideoWriterInput
                                                                                               sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    
    NSParameterAssert(self.assetVideoWriterInput);
    
    NSParameterAssert([self.assetWriter canAddInput:self.assetVideoWriterInput]);
    
    if ([self.assetWriter canAddInput:self.assetVideoWriterInput])
        
        NSLog(@"I can add this input");
    
    else
        
        NSLog(@"i can't add this input");
    
    
    
    
    // Add the audio input
    
    AudioChannelLayout acl;
    
    bzero( &acl, sizeof(acl));
    
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    
    
    
    NSDictionary* audioOutputSettings = nil;
    
    //    audioOutputSettings = [ NSDictionary dictionaryWithObjectsAndKeys:
    
    //                           [ NSNumber numberWithInt: kAudioFormatAppleLossless ], AVFormatIDKey,
    
    //                           [ NSNumber numberWithInt: 16 ], AVEncoderBitDepthHintKey,
    
    //                           [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
    
    //                           [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
    
    //                           [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
    
    //                           nil ];
    
    audioOutputSettings = [ NSDictionary dictionaryWithObjectsAndKeys:
                           
                           [ NSNumber numberWithInt: kAudioFormatMPEG4AAC ], AVFormatIDKey,
                           
                           [ NSNumber numberWithInt:64000], AVEncoderBitRateKey,
                           
                           [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
                           
                           [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,                                      
                           
                           [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                           
                           nil ];
    
    self.assetAudioWriterInput = [AVAssetWriterInput
                         assetWriterInputWithMediaType: AVMediaTypeAudio
                         outputSettings: audioOutputSettings];
    self.assetAudioWriterInput.expectsMediaDataInRealTime = YES;
    
    // add input
    [self.assetWriter addInput:self.assetVideoWriterInput];
    [self.assetWriter addInput:self.assetAudioWriterInput];
    
}

#pragma mark -
#pragma mark - Memeber

- (void)startRecording {
    
    if (self.isRecording) {
        return;
    }
    
    self.isRecording = YES;
    
}

- (void)stopRecording {

//    [self.fileOutput stopRecording];
    __weak typeof(self) weakSelf = self;
    if ([_assetWriter respondsToSelector:@selector(finishWritingWithCompletionHandler:)]) {
        // Running iOS 6
        [_assetWriter finishWritingWithCompletionHandler:^{
            weakSelf.isRecording = NO;
        }];
    }
    else {
        // Not running iOS 6
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [_assetWriter finishWriting];
        self.isRecording = NO;
#pragma clang diagnostic pop
    }
    
}

#pragma mark -
#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (!self.isRecording) {
        return;
    }
    
    static int frame = 0;
    
    CMTime lastSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
        if( frame == 0 && self.assetWriter.status != AVAssetWriterStatusWriting  )
    
        {
    
            [self.assetWriter startWriting];
    
            [self.assetWriter startSessionAtSourceTime:lastSampleTime];
    
        }
    
    if (captureOutput == self.videoOutput)
        
    {
        if( self.assetWriter.status > AVAssetWriterStatusWriting )
            
        {
            
            NSLog(@"Warning: writer status is %d", self.assetWriter.status);
            
            if( self.assetWriter.status == AVAssetWriterStatusFailed )
                
                NSLog(@"Error: %@", self.assetWriter.error);
            
            return;
            
        }
        
        if ([self.assetVideoWriterInput isReadyForMoreMediaData])
            
            if( ![self.assetVideoWriterInput appendSampleBuffer:sampleBuffer] )
                
                NSLog(@"Unable to write to video input");
        
            else
                
                NSLog(@"already write vidio");
        
        
    }
    
    else if (captureOutput == self.audioOutput)
    {
        
        if( self.assetWriter.status > AVAssetWriterStatusWriting )
            
        {
            
            NSLog(@"Warning: writer status is %d", self.assetWriter.status);
            
            if( self.assetWriter.status == AVAssetWriterStatusFailed )
                
                NSLog(@"Error: %@", self.assetWriter.error);
            
            return;
            
        }
        
        
        if ([self.assetAudioWriterInput isReadyForMoreMediaData])
            
            if( ![self.assetAudioWriterInput appendSampleBuffer:sampleBuffer] )
                
                NSLog(@"Unable to write to audio input");
        
            else
                
                NSLog(@"already write audio");
        
    }
    
    //    if (frame == FrameCount)
    //
    //    {
    //    
    //        [self closeVideoWriter];
    //    
    //    }

}

@end
