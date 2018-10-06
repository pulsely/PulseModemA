//
//  EZMicrophone.m
//  EZAudio
//
//  Created by Syed Haris Ali on 9/2/13.
//  Copyright (c) 2015 Syed Haris Ali. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "EZMicrophone.h"
#import "EZAudioFloatConverter.h"
#import "EZAudioUtilities.h"
#import "EZAudioDevice.h"


float *convertedBuffer = NULL;
AudioUnit *audioUnit_ = NULL;


// Multimon imports starts


// iOS custom imports
#include <CoreAudio/CoreAudioTypes.h>
#include <CoreFoundation/CoreFoundation.h>

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

// multimon imports
#include "multimon.h"
#include <stdio.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#ifndef _MSC_VER
#include <unistd.h>
#endif
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <getopt.h>

#ifdef SUN_AUDIO
#include <sys/audioio.h>
#include <stropts.h>
#include <sys/conf.h>
#elif PULSE_AUDIO
#include <pulse/simple.h>
#include <pulse/error.h>
#elif WIN32_AUDIO
//see win32_soundin.c
#elif DUMMY_AUDIO
// NO AUDIO FOR OSX :/
#else /* SUN_AUDIO */
#include <sys/soundcard.h>
#include <sys/ioctl.h>
//#include <sys/wait.h>
#endif /* SUN_AUDIO */

#ifndef ONLY_RAW
#include <sys/wait.h>
#endif

/* ---------------------------------------------------------------------- */

static const char *allowed_types[] = {
    "raw", "aiff", "au", "hcom", "sf", "voc", "cdr", "dat",
    "smp", "wav", "maud", "vwe", "mp3", "mp4", "ogg", "flac", NULL
};

/* ---------------------------------------------------------------------- */

static const struct demod_param *dem[] = { ALL_DEMOD };

#define NUMDEMOD (sizeof(dem)/sizeof(dem[0]))

static struct demod_state dem_st[NUMDEMOD];
static unsigned int dem_mask[(NUMDEMOD+31)/32];

#define MASK_SET(n) dem_mask[(n)>>5] |= 1<<((n)&0x1f)
#define MASK_RESET(n) dem_mask[(n)>>5] &= ~(1<<((n)&0x1f))
#define MASK_ISSET(n) (dem_mask[(n)>>5] & 1<<((n)&0x1f))

/* ---------------------------------------------------------------------- */

static int verbose_level = 0;
static int repeatable_sox = 0;
static int mute_sox = 0;
static int integer_only = true;
static bool dont_flush = false;
static bool is_startline = true;
static int timestamp = 0;
static char *label = NULL;

extern int pocsag_mode;
extern int pocsag_invert_input;
extern int pocsag_error_correction;
extern int pocsag_show_partial_decodes;
extern int pocsag_heuristic_pruning;
extern int pocsag_prune_empty;

extern int aprs_mode;
extern int cw_dit_length;
extern int cw_gap_length;
extern int cw_threshold;
extern bool cw_disable_auto_threshold;
extern bool cw_disable_auto_timing;


/* ---------------------------------------------------------------------- */

static const char usage_str[] = "\n"
"Usage: %s [file] [file] [file] ...\n"
"  If no [file] is given, input will be read from your default sound\n"
"  hardware. A filename of \"-\" denotes standard input.\n"
"  -t <type>  : Input file type (any other type than raw requires sox)\n"
"  -a <demod> : Add demodulator\n"
"  -s <demod> : Subtract demodulator\n"
"  -c         : Remove all demodulators (must be added with -a <demod>)\n"
"  -q         : Quiet\n"
"  -v <level> : Level of verbosity (e.g. '-v 3')\n"
"               For POCSAG and MORSE_CW '-v1' prints decoding statistics.\n"
"  -h         : This help\n"
"  -A         : APRS mode (TNC2 text output)\n"
"  -m         : Mute SoX warnings\n"
"  -r         : Call SoX in repeatable mode (e.g. fixed random seed for dithering)\n"
"  -n         : Don't flush stdout, increases performance.\n"
"  -e         : POCSAG: Hide empty messages.\n"
"  -u         : POCSAG: Heuristically prune unlikely decodes.\n"
"  -i         : POCSAG: Inverts the input samples. Try this if decoding fails.\n"
"  -p         : POCSAG: Show partially received messages.\n"
"  -f <mode>  : POCSAG: Disables auto-detection and forces decoding of data as <mode>\n"
"                       (<mode> can be 'numeric', 'alpha' and 'skyper')\n"
"  -b <level> : POCSAG: BCH bit error correction level. Set 0 to disable, default is 2.\n"
"                       Lower levels increase performance and lower false positives.\n"
"  -o         : CW: Set threshold for dit detection (default: 500)\n"
"  -d         : CW: Dit length in ms (default: 50)\n"
"  -g         : CW: Gap length in ms (default: 50)\n"
"  -x         : CW: Disable auto threshold detection\n"
"  -y         : CW: Disable auto timing detection\n"
"  --timestamp: Add a time stamp in front of every printed line\n"
"  --label    : Add a label to the front of every printed line\n"
"   Raw input requires one channel, 16 bit, signed integer (platform-native)\n"
"   samples at the demodulator's input sampling rate, which is\n"
"   usually 22050 Hz. Raw input is assumed and required if piped input is used.\n";


/* ---------------------------------------------------------------------- */

void process_buffer_wav(float *float_buf, short *short_buf, unsigned int len)
{
    for (int i = 0; (unsigned int) i <  NUMDEMOD; i++)
        if (MASK_ISSET(i) && dem[i]->demod)
        {
            // NSLog(@">>> %.6f %d", *float_buf, *short_buf);
            // sample values:
            /// >>> -0.000153 -2
            /// >>> 0.000000 -1
            
            buffer_t buffer = {short_buf, float_buf};
            dem[i]->demod(dem_st+i, buffer, len);
        }
}


/* ---------------------------------------------------------------------- */

static void input_file_wav(unsigned int sample_rate, unsigned int overlap,
                           const char *fname, const char *type)
{
    struct stat statbuf;
    int pipedes[2];
    int pid = 0, soxstat;
    int fd;
    int i;
    short buffer[256]; //8192];
    float fbuf[256 * 2]; //16384
    unsigned int fbuf_cnt = 0;
    short *sp;
    
    /*
     * if the input type is not raw, sox is started to convert the
     * samples to the requested format
     */
    if (!strcmp(fname, "-"))
    {
        // read from stdin and force raw input
        fd = 0;
        type = "raw";
    }
    else if (!type || !strcmp(type, "raw")) {
        if ((fd = open(fname, O_RDONLY)) < 0) {
            perror("open");
        }
    }
    
#ifndef ONLY_RAW
    else {
        if (stat(fname, &statbuf)) {
            perror("stat");
            exit(10);
        }
        if (pipe(pipedes)) {
            perror("pipe");
            exit(10);
        }
        if (!(pid = fork())) {
            char srate[8];
            /*
             * child starts here... first set up filedescriptors,
             * then start sox...
             */
            sprintf(srate, "%d", sample_rate);
            close(pipedes[0]); /* close reading pipe end */
            close(1); /* close standard output */
            if (dup2(pipedes[1], 1) < 0)
                perror("dup2");
            close(pipedes[1]); /* close writing pipe end */
            execlp("sox", "sox", repeatable_sox?"-R":"-V2", mute_sox?"-V1":"-V2",
                   "-t", type, fname,
                   "-t", "raw", "-esigned-integer", "-b16", "-r", srate, "-", "remix", "1",
                   NULL);
            perror("execlp");
            exit(10);
        }
        if (pid < 0) {
            perror("fork");
            exit(10);
        }
        close(pipedes[1]); /* close writing pipe end */
        fd = pipedes[0];
    }
#endif
    
    /*
     * demodulate
     */
    for (;;) {
        i = read(fd, sp = buffer, sizeof(buffer));
        
        if (i < 0 && errno != EAGAIN) {
            perror("read");
            exit(4);
        }
        if (!i)
            break;
        if (i > 0) {
            if(integer_only)
            {
                fbuf_cnt = i/sizeof(buffer[0]);
            }
            else
            {
                for (; (unsigned int) i >= sizeof(buffer[0]); i -= sizeof(buffer[0]), sp++) {
                    
                    // sp is the actual values?
                    // NSLog(@"size of buffer: %d", sizeof(buffer[0])); --> 2
                    // NSLog(@"sp: %d", *sp);
                    
                    fbuf[fbuf_cnt++] = (*sp) * (1.0f/32768.0f);
                    
                    //NSLog(@"DEBUG>%.10f", (*sp) * (1.0f/32768.0f));
                }
                if (i)
                    fprintf(stderr, "warning: noninteger number of samples read\n");
            }
            
            // process the buffer when the: fbuf_cnt > overlap
            if (fbuf_cnt > overlap) {
                //NSLog(@">> fbuf_cnt %d > overlap %d", fbuf_cnt, overlap);
                process_buffer_wav(fbuf, buffer, fbuf_cnt-overlap);
                
                memmove(fbuf, fbuf+fbuf_cnt-overlap, overlap*sizeof(fbuf[0]));
                fbuf_cnt = overlap;
            }
        }
    }
    close(fd);
    
#ifndef ONLY_RAW
    waitpid(pid, &soxstat, 0);
#endif
}




// Above are original from multimon helper



// Multimon import ends

//------------------------------------------------------------------------------
#pragma mark - Data Structures
//------------------------------------------------------------------------------

typedef struct EZMicrophoneInfo
{
    AudioUnit                     audioUnit;
    AudioBufferList              *audioBufferList;
    float                       **floatData;
    AudioStreamBasicDescription   inputFormat;
    AudioStreamBasicDescription   streamFormat;
} EZMicrophoneInfo;

//------------------------------------------------------------------------------
#pragma mark - Callbacks
//------------------------------------------------------------------------------

static OSStatus EZAudioMicrophoneCallback(void                       *inRefCon,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp       *inTimeStamp,
                                          UInt32                      inBusNumber,
                                          UInt32                      inNumberFrames,
                                          AudioBufferList            *ioData);

//------------------------------------------------------------------------------
#pragma mark - EZMicrophone (Interface Extension)
//------------------------------------------------------------------------------

@interface EZMicrophone ()
@property (nonatomic, strong) EZAudioFloatConverter *floatConverter;
@property (nonatomic, assign) EZMicrophoneInfo      *info;
@end

@implementation EZMicrophone

//------------------------------------------------------------------------------
#pragma mark - Dealloc
//------------------------------------------------------------------------------

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [EZAudioUtilities checkResult:AudioUnitUninitialize(self.info->audioUnit)
                        operation:"Failed to unintialize audio unit for microphone"];
    [EZAudioUtilities freeBufferList:self.info->audioBufferList];
    [EZAudioUtilities freeFloatBuffers:self.info->floatData
                      numberOfChannels:self.info->streamFormat.mChannelsPerFrame];
    free(self.info);
}

//------------------------------------------------------------------------------
#pragma mark - Initialization
//------------------------------------------------------------------------------

- (id)init
{
    self = [super init];
    if(self)
    {
        self.info = (EZMicrophoneInfo *)malloc(sizeof(EZMicrophoneInfo));
        memset(self.info, 0, sizeof(EZMicrophoneInfo));
        [self setup];
    }
    return self;
}

//------------------------------------------------------------------------------

- (EZMicrophone *)initWithMicrophoneDelegate:(id<EZMicrophoneDelegate>)delegate
{
    self = [super init];
    if(self)
    {
        self.info = (EZMicrophoneInfo *)malloc(sizeof(EZMicrophoneInfo));
        memset(self.info, 0, sizeof(EZMicrophoneInfo));
        _delegate = delegate;
        [self setup];
    }
    return self;
}

//------------------------------------------------------------------------------

-(EZMicrophone *)initWithMicrophoneDelegate:(id<EZMicrophoneDelegate>)delegate
            withAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription
{
    self = [self initWithMicrophoneDelegate:delegate];
    if(self)
    {
        [self setAudioStreamBasicDescription:audioStreamBasicDescription];
    }
    return self;
}

//------------------------------------------------------------------------------

- (EZMicrophone *)initWithMicrophoneDelegate:(id<EZMicrophoneDelegate>)delegate
                           startsImmediately:(BOOL)startsImmediately
{
    self = [self initWithMicrophoneDelegate:delegate];
    if(self)
    {
        startsImmediately ? [self startFetchingAudio] : -1;
    }
    return self;
}

//------------------------------------------------------------------------------

-(EZMicrophone *)initWithMicrophoneDelegate:(id<EZMicrophoneDelegate>)delegate
            withAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription
                          startsImmediately:(BOOL)startsImmediately
{
    self = [self initWithMicrophoneDelegate:delegate
            withAudioStreamBasicDescription:audioStreamBasicDescription];
    if(self)
    {
        startsImmediately ? [self startFetchingAudio] : -1;
    }
    return self;
}

//------------------------------------------------------------------------------
#pragma mark - Class Initializers
//------------------------------------------------------------------------------

+ (EZMicrophone *)microphoneWithDelegate:(id<EZMicrophoneDelegate>)delegate
{
    return [[EZMicrophone alloc] initWithMicrophoneDelegate:delegate];
}

//------------------------------------------------------------------------------

+ (EZMicrophone *)microphoneWithDelegate:(id<EZMicrophoneDelegate>)delegate
         withAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription
{
    return [[EZMicrophone alloc] initWithMicrophoneDelegate:delegate
                            withAudioStreamBasicDescription:audioStreamBasicDescription];
}

//------------------------------------------------------------------------------

+ (EZMicrophone *)microphoneWithDelegate:(id<EZMicrophoneDelegate>)delegate
                        startsImmediately:(BOOL)startsImmediately
{
    return [[EZMicrophone alloc] initWithMicrophoneDelegate:delegate
                                          startsImmediately:startsImmediately];
}

//------------------------------------------------------------------------------

+ (EZMicrophone *)microphoneWithDelegate:(id<EZMicrophoneDelegate>)delegate
         withAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription
                       startsImmediately:(BOOL)startsImmediately
{
    return [[EZMicrophone alloc] initWithMicrophoneDelegate:delegate
                            withAudioStreamBasicDescription:audioStreamBasicDescription
                                          startsImmediately:startsImmediately];
}

//------------------------------------------------------------------------------
#pragma mark - Singleton
//------------------------------------------------------------------------------

+ (EZMicrophone *)sharedMicrophone
{
    static EZMicrophone *_sharedMicrophone = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedMicrophone = [[EZMicrophone alloc] init];
    });
    return _sharedMicrophone;
}

//------------------------------------------------------------------------------
#pragma mark - Setup
//------------------------------------------------------------------------------

- (void)setup
{
    // Create an input component description for mic input
    AudioComponentDescription inputComponentDescription;
    inputComponentDescription.componentType = kAudioUnitType_Output;
    inputComponentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
#if TARGET_OS_IPHONE
    inputComponentDescription.componentSubType = kAudioUnitSubType_RemoteIO;
#elif TARGET_OS_MAC
    inputComponentDescription.componentSubType = kAudioUnitSubType_HALOutput;
#endif
    // The following must be set to zero unless a specific value is requested.
    inputComponentDescription.componentFlags = 0;
    inputComponentDescription.componentFlagsMask = 0;
    
    // get the first matching component
    AudioComponent inputComponent = AudioComponentFindNext( NULL , &inputComponentDescription);
    NSAssert(inputComponent, @"Couldn't get input component unit!");
    
    // create new instance of component
    [EZAudioUtilities checkResult:AudioComponentInstanceNew(inputComponent, &self.info->audioUnit)
                        operation:"Failed to get audio component instance"];
    
#if TARGET_OS_IPHONE
    // must enable input scope for remote IO unit
    UInt32 flag = 1;
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioOutputUnitProperty_EnableIO,
                                                       kAudioUnitScope_Input,
                                                       1,
                                                       &flag,
                                                       sizeof(flag))
                        operation:"Couldn't enable input on remote IO unit."];
#endif
    [self setDevice:[EZAudioDevice currentInputDevice]];
    
    UInt32 propSize = sizeof(self.info->inputFormat);
    [EZAudioUtilities checkResult:AudioUnitGetProperty(self.info->audioUnit,
                                                       kAudioUnitProperty_StreamFormat,
                                                       kAudioUnitScope_Input,
                                                       1,
                                                       &self.info->inputFormat,
                                                       &propSize)
                        operation:"Failed to get stream format of microphone input scope"];
#if TARGET_OS_IPHONE
    self.info->inputFormat.mSampleRate = [[AVAudioSession sharedInstance] sampleRate];
    NSAssert(self.info->inputFormat.mSampleRate, @"Expected AVAudioSession sample rate to be greater than 0.0. Did you setup the audio session?");
#elif TARGET_OS_MAC
#endif
    [self setAudioStreamBasicDescription:[self defaultStreamFormat]];
    
    // render callback
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = EZAudioMicrophoneCallback;
    renderCallbackStruct.inputProcRefCon = (__bridge void *)(self);
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioOutputUnitProperty_SetInputCallback,
                                                       kAudioUnitScope_Global,
                                                       1,
                                                       &renderCallbackStruct,
                                                       sizeof(renderCallbackStruct))
                        operation:"Failed to set render callback"];
    
    [EZAudioUtilities checkResult:AudioUnitInitialize(self.info->audioUnit)
                        operation:"Failed to initialize input unit"];
    
    // setup notifications
    [self setupNotifications];
}

- (void)setupNotifications
{
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(microphoneWasInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(microphoneRouteChanged:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
#elif TARGET_OS_MAC
#endif
}

//------------------------------------------------------------------------------
#pragma mark - Notifications
//------------------------------------------------------------------------------

#if TARGET_OS_IPHONE

- (void)microphoneWasInterrupted:(NSNotification *)notification
{
    AVAudioSessionInterruptionType type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    switch (type)
    {
        case AVAudioSessionInterruptionTypeBegan:
        {
            [self stopFetchingAudio];
            break;
        }
        case AVAudioSessionInterruptionTypeEnded:
        {
            AVAudioSessionInterruptionOptions option = [notification.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
            if (option == AVAudioSessionInterruptionOptionShouldResume)
            {
                [self startFetchingAudio];
            }
            break;
        }
        default:
        {
            break;
        }
    }
}

//------------------------------------------------------------------------------

- (void)microphoneRouteChanged:(NSNotification *)notification
{
    EZAudioDevice *device = [EZAudioDevice currentInputDevice];
    [self setDevice:device];
}

#elif TARGET_OS_MAC
#endif

//------------------------------------------------------------------------------
#pragma mark - Events
//------------------------------------------------------------------------------

-(void)startFetchingAudio
{
    //
    // Start output unit
    //
    [EZAudioUtilities checkResult:AudioOutputUnitStart(self.info->audioUnit)
                        operation:"Failed to start microphone audio unit"];
    
    //
    // Notify delegate
    //
    if ([self.delegate respondsToSelector:@selector(microphone:changedPlayingState:)])
    {
        [self.delegate microphone:self changedPlayingState:YES];
    }
}

//------------------------------------------------------------------------------

-(void)stopFetchingAudio
{
    //
    // Stop output unit
    //
    [EZAudioUtilities checkResult:AudioOutputUnitStop(self.info->audioUnit)
                        operation:"Failed to stop microphone audio unit"];
    
    //
    // Notify delegate
    //
    if ([self.delegate respondsToSelector:@selector(microphone:changedPlayingState:)])
    {
        [self.delegate microphone:self changedPlayingState:NO];
    }
}

//------------------------------------------------------------------------------
#pragma mark - Getters
//------------------------------------------------------------------------------

-(AudioStreamBasicDescription)audioStreamBasicDescription
{
    return self.info->streamFormat;
}

//------------------------------------------------------------------------------

-(AudioUnit *)audioUnit
{
    return &self.info->audioUnit;
}

//------------------------------------------------------------------------------

- (UInt32)maximumBufferSize
{
    UInt32 maximumBufferSize;
    UInt32 propSize = sizeof(maximumBufferSize);
    [EZAudioUtilities checkResult:AudioUnitGetProperty(self.info->audioUnit,
                                                       kAudioUnitProperty_MaximumFramesPerSlice,
                                                       kAudioUnitScope_Global,
                                                       0,
                                                       &maximumBufferSize,
                                                       &propSize)
                        operation:"Failed to get maximum number of frames per slice"];
    return maximumBufferSize;
}

//------------------------------------------------------------------------------
#pragma mark - Setters
//------------------------------------------------------------------------------

- (void)setMicrophoneOn:(BOOL)microphoneOn
{
    _microphoneOn = microphoneOn;
    if (microphoneOn)
    {
        [self startFetchingAudio];
    }
    else {
        [self stopFetchingAudio];
    }
}

//------------------------------------------------------------------------------

- (void)setAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd
{
    if (self.floatConverter)
    {
        [EZAudioUtilities freeBufferList:self.info->audioBufferList];
        [EZAudioUtilities freeFloatBuffers:self.info->floatData
                          numberOfChannels:self.info->streamFormat.mChannelsPerFrame];
    }
    
    //
    // Set new stream format
    //
    self.info->streamFormat = asbd;
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioUnitProperty_StreamFormat,
                                                       kAudioUnitScope_Input,
                                                       0,
                                                       &asbd,
                                                       sizeof(asbd))
                        operation:"Failed to set stream format on input scope"];
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioUnitProperty_StreamFormat,
                                                       kAudioUnitScope_Output,
                                                       1,
                                                       &asbd,
                                                       sizeof(asbd))
                        operation:"Failed to set stream format on output scope"];
    
    //
    // Allocate scratch buffers
    //
    UInt32 maximumBufferSize = [self maximumBufferSize];
    BOOL isInterleaved = [EZAudioUtilities isInterleaved:asbd];
    UInt32 channels = asbd.mChannelsPerFrame;
    self.floatConverter = [[EZAudioFloatConverter alloc] initWithInputFormat:asbd];
    self.info->floatData = [EZAudioUtilities floatBuffersWithNumberOfFrames:maximumBufferSize
                                                      numberOfChannels:channels];
    self.info->audioBufferList = [EZAudioUtilities audioBufferListWithNumberOfFrames:maximumBufferSize
                                                                    numberOfChannels:channels
                                                                         interleaved:isInterleaved];
    //
    // Notify delegate
    //
    if ([self.delegate respondsToSelector:@selector(microphone:hasAudioStreamBasicDescription:)])
    {
        [self.delegate microphone:self hasAudioStreamBasicDescription:asbd];
    }
}

//------------------------------------------------------------------------------

- (void)setDevice:(EZAudioDevice *)device
{
#if TARGET_OS_IPHONE
    
    // if the devices are equal then ignore
    if ([device isEqual:self.device])
    {
        return;
    }
    
    NSError *error;
    [[AVAudioSession sharedInstance] setPreferredInput:device.port error:&error];
    if (error)
    {
        NSLog(@"Error setting input device port (%@), reason: %@",
              device.port,
              error.localizedDescription);
    }
    else
    {
        if (device.dataSource)
        {
            [[AVAudioSession sharedInstance] setInputDataSource:device.dataSource error:&error];
            if (error)
            {
                NSLog(@"Error setting input data source (%@), reason: %@",
                      device.dataSource,
                      error.localizedDescription);
            }
        }
    }
    
#elif TARGET_OS_MAC
    UInt32 inputEnabled = device.inputChannelCount > 0;
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioOutputUnitProperty_EnableIO,
                                                       kAudioUnitScope_Input,
                                                       1,
                                                       &inputEnabled,
                                                       sizeof(inputEnabled))
                        operation:"Failed to set flag on device input"];
    
    UInt32 outputEnabled = device.outputChannelCount > 0;
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioOutputUnitProperty_EnableIO,
                                                       kAudioUnitScope_Output,
                                                       0,
                                                       &outputEnabled,
                                                       sizeof(outputEnabled))
                        operation:"Failed to set flag on device output"];
    
    AudioDeviceID deviceId = device.deviceID;
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->audioUnit,
                                                       kAudioOutputUnitProperty_CurrentDevice,
                                                       kAudioUnitScope_Global,
                                                       0,
                                                       &deviceId,
                                                       sizeof(AudioDeviceID))
                        operation:"Couldn't set default device on I/O unit"];
#endif
    
    //
    // Store device
    //
    _device = device;
    
    //
    // Notify delegate
    //
    if ([self.delegate respondsToSelector:@selector(microphone:changedDevice:)])
    {
        [self.delegate microphone:self changedDevice:device];
    }
}

//------------------------------------------------------------------------------
#pragma mark - Output
//------------------------------------------------------------------------------

- (void)setOutput:(EZOutput *)output
{
    _output = output;
    _output.inputFormat = self.audioStreamBasicDescription;
    _output.dataSource = self;
}

//------------------------------------------------------------------------------
#pragma mark - EZOutputDataSource
//------------------------------------------------------------------------------

- (OSStatus)        output:(EZOutput *)output
 shouldFillAudioBufferList:(AudioBufferList *)audioBufferList
        withNumberOfFrames:(UInt32)frames
                 timestamp:(const AudioTimeStamp *)timestamp
{
    memcpy(audioBufferList,
           self.info->audioBufferList,
           sizeof(AudioBufferList) + (self.info->audioBufferList->mNumberBuffers - 1)*sizeof(AudioBuffer));
    return noErr;
}

//------------------------------------------------------------------------------
#pragma mark - Subclass
//------------------------------------------------------------------------------

- (AudioStreamBasicDescription)defaultStreamFormat
{
    return [EZAudioUtilities floatFormatWithNumberOfChannels:[self numberOfChannels]
                                                  sampleRate:self.info->inputFormat.mSampleRate];
}

//------------------------------------------------------------------------------

- (UInt32)numberOfChannels
{
#if TARGET_OS_IPHONE
    return 1;
#elif TARGET_OS_MAC
    return (UInt32)self.device.inputChannelCount;
#endif
}

//------------------------------------------------------------------------------
- (void)initMultimon {
    //int argc;
    char *argv[20];
    
    //int c;
    int errflg = 0;
    int quietflg = 0;
    int i;
    char **itype;
    int mask_first = 1;
    int sample_rate = -1;
    unsigned int overlap = 0;
    char *input_type = "hw";
    
    //    static struct option long_options[] =
    //    {
    //        {"timestamp", no_argument, &timestamp, 1},
    //        {"label", required_argument, NULL, 'l'},
    //        {0, 0, 0, 0}
    //    };
    
    // Option A
    aprs_mode = 1;
    memset(dem_mask, 0, sizeof(dem_mask));
    mask_first = 0;
    for (i = 0; (unsigned int) i < NUMDEMOD; i++)
        if (!strcasecmp("AFSK1200", dem[i]->name)) {
            MASK_SET(i);
            break;
        }
    // Case "t"
    for (itype = (char **)allowed_types; *itype; itype++) {
        char *optarg = "raw";
        if (!strcmp(*itype, optarg)) {
            input_type = *itype;
            goto intypefound;
        }
    }
intypefound:
    1;
    
    // main loop
    if ( !quietflg )
    { // pay heed to the quietflg
        fprintf(stderr, "multimon-ng 1.1.5\n"
                "  (C) 1996/1997 by Tom Sailer HB9JNX/AE4WA\n"
                "  (C) 2012-2018 by Elias Oenal\n"
                "Available demodulators:");
        for (i = 0; (unsigned int) i < NUMDEMOD; i++) {
            fprintf(stderr, " %s", dem[i]->name);
        }
        fprintf(stderr, "\n");
    }
    
    if (errflg) {
        (void)fprintf(stderr, usage_str, argv[0]);
        exit(2);
    }
    if (mask_first)
        memset(dem_mask, 0xff, sizeof(dem_mask));
    //    if (!quietflg)
    //        fprintf(stdout, "Enabled demodulators:");
    
    for (i = 0; (unsigned int) i < NUMDEMOD; i++)
        if (MASK_ISSET(i)) {
            if (!quietflg)
                fprintf(stdout, " %s", dem[i]->name);       //Print demod name
            if(dem[i]->float_samples) integer_only = false; //Enable float samples on demand
            memset(dem_st+i, 0, sizeof(dem_st[i]));
            dem_st[i].dem_par = dem[i];
            if (dem[i]->init)
                dem[i]->init(dem_st+i);
            if (sample_rate == -1)
                sample_rate = dem[i]->samplerate;
            else if ( (unsigned int) sample_rate != dem[i]->samplerate) {
                if (!quietflg)
                    fprintf(stdout, "\n");
                fprintf(stderr, "Error: Current sampling rate %d, "
                        " demodulator \"%s\" requires %d\n",
                        sample_rate, dem[i]->name, dem[i]->samplerate);
                exit(3);
            }
            if (dem[i]->overlap > overlap)
                overlap = dem[i]->overlap;
        }
    if (!quietflg)
        fprintf(stdout, "\n");
    // NSLog(@"overlap: %d", overlap);
    // Decide using raw input, or file
    if (ENABLE_AUDIO_TEST_RAW) {
        const char *filename = [[[NSBundle mainBundle] pathForResource: @"output" ofType: @"raw"] cStringUsingEncoding: NSUTF8StringEncoding];
        input_file_wav(sample_rate, overlap, filename, input_type);
    }
    // Don't need this anymore
    //[self input_ios];
}


@end

//------------------------------------------------------------------------------
#pragma mark - Callbacks
//------------------------------------------------------------------------------

static OSStatus EZAudioMicrophoneCallback(void                       *inRefCon,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp       *inTimeStamp,
                                          UInt32                      inBusNumber,
                                          UInt32                      inNumberFrames,
                                          AudioBufferList            *ioData)
{
    EZMicrophone *microphone = (__bridge EZMicrophone *)inRefCon;
    EZMicrophoneInfo *info = (EZMicrophoneInfo *)microphone.info;
    
    //
    // Make sure the size of each buffer in the stored buffer array
    // is properly set using the actual number of frames coming in!
    //
    for (int i = 0; i < info->audioBufferList->mNumberBuffers; i++) {
        info->audioBufferList->mBuffers[i].mDataByteSize = inNumberFrames * info->streamFormat.mBytesPerFrame;
    }
    
    //
    // Render audio into buffer
    //
    OSStatus result = AudioUnitRender(info->audioUnit,
                                      ioActionFlags,
                                      inTimeStamp,
                                      inBusNumber,
                                      inNumberFrames,
                                      info->audioBufferList);
    
    // insert the audio process of multimon here
    UInt32 numFrames = inNumberFrames;
    if(convertedBuffer == NULL) {
        // Lazy initialization of this buffer is necessary because we don't
        // know the frame count until the first callback
        convertedBuffer = (float*)malloc(sizeof(float) * numFrames);
    }
    SInt16 *inputFrames = (SInt16*)(info->audioBufferList->mBuffers->mData);
    for(int i = 0; i < numFrames; i++) {
        convertedBuffer[i] = (float)inputFrames[i] / 32768.0f;
    }
    
    for (int i = 0; (unsigned int) i <  NUMDEMOD; i++)
        if (MASK_ISSET(i) && dem[i]->demod)
        {
            buffer_t b = {inputFrames, convertedBuffer};
            dem[i]->demod(dem_st+i, b, numFrames);
        }

    
    //
    // Notify delegate of new buffer list to process
    //
    if ([microphone.delegate respondsToSelector:@selector(microphone:hasBufferList:withBufferSize:withNumberOfChannels:)])
    {
        [microphone.delegate microphone:microphone
                          hasBufferList:info->audioBufferList
                         withBufferSize:inNumberFrames
                   withNumberOfChannels:info->streamFormat.mChannelsPerFrame];
    }
    
    //
    // Notify delegate of new float data processed
    //
    if ([microphone.delegate respondsToSelector:@selector(microphone:hasAudioReceived:withBufferSize:withNumberOfChannels:)])
    {
        //
        // Convert to float
        //
        [microphone.floatConverter convertDataFromAudioBufferList:info->audioBufferList
                                               withNumberOfFrames:inNumberFrames
                                                   toFloatBuffers:info->floatData];
        [microphone.delegate microphone:microphone
                       hasAudioReceived:info->floatData
                         withBufferSize:inNumberFrames
                   withNumberOfChannels:info->streamFormat.mChannelsPerFrame];
    }
    
    return result;
}
