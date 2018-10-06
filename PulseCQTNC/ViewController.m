//
//  ViewController.m
//  CoreGraphicsWaveform
//
//  Created by Syed Haris Ali on 12/1/13.
//  Updated by Syed Haris Ali on 1/23/16.
//  Copyright (c) 2013 Syed Haris Ali. All rights reserved.
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
//

#import "RFReceiveController.h"
#include "multimon.h"
#import <NSLogger/NSLogger.h>

float *convertedBuffer = NULL;
AudioUnit *audioUnit_ = NULL;


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

//------------------------------------------------------------------------------
#pragma mark - ViewController (Interface Extension)
//------------------------------------------------------------------------------

@interface RFReceiveController ()
@property (nonatomic, strong) NSArray *inputs;
@end

//------------------------------------------------------------------------------
#pragma mark - ViewController (Implementation)
//------------------------------------------------------------------------------

@implementation RFReceiveController

//------------------------------------------------------------------------------
#pragma mark - View Style
//------------------------------------------------------------------------------

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

//------------------------------------------------------------------------------
#pragma mark - Setup
//------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];

    //
    // Setup the AVAudioSession. EZMicrophone will not work properly on iOS
    // if you don't do this!
    //
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error)
    {
        LoggerApp(1, @"Error setting up audio session category: %@", error.localizedDescription);
    }
    [session setActive:YES error:&error];
    if (error)
    {
        LoggerApp(1, @"Error setting up audio session active: %@", error.localizedDescription);
    }
    
    
    float aBufferLength = COREAUDIO_BUFFER_LENGTH; // In seconds
    AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(aBufferLength), &aBufferLength);

//    NSError *setCategoryError = nil;
//    if (![session setCategory:AVAudioSessionCategoryPlayback
//                  withOptions:AVAudioSessionCategoryOptionMixWithOthers
//                        error:&setCategoryError]) {
//        // handle error
//    }

    
//    double rate = 22050.0;
//    [session setPreferredSampleRate: rate error:&error];
//    [session setPreferredOutputNumberOfChannels: 1 error:&error];
//
    //
    // Customizing the audio plot's look
    //
    
    //
    // Background color
    //
    self.audioPlot.backgroundColor = [UIColor colorWithRed:0.984 green:0.471 blue:0.525 alpha:1.0];

    //
    // Waveform color
    //
    self.audioPlot.color = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];

    //
    // Plot type
    //
    self.audioPlot.plotType = EZPlotTypeBuffer;

    
    // Multimon customization: set AudioStreamBasicDescription
    AudioStreamBasicDescription streamDescription;
    // You might want to replace this with a different value, but keep in mind that the
    // iPhone does not support all sample rates. 8kHz, 22kHz, and 44.1kHz should all work.
    streamDescription.mSampleRate = 22050;
    // Yes, I know you probably want floating point samples, but the iPhone isn't going
    // to give you floating point data. You'll need to make the conversion by hand from
    // linear PCM <-> float.
    streamDescription.mFormatID = kAudioFormatLinearPCM;
    // This part is important!
    streamDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger |
    kAudioFormatFlagsNativeEndian |
    kAudioFormatFlagIsPacked;
    // Not sure if the iPhone supports recording >16-bit audio, but I doubt it.
    streamDescription.mBitsPerChannel = 16;
    // 1 sample per frame, will always be 2 as long as 16-bit samples are being used
    streamDescription.mBytesPerFrame = 2;
    // Record in mono. Use 2 for stereo, though I don't think the iPhone does true stereo recording
    streamDescription.mChannelsPerFrame = 1;
    streamDescription.mBytesPerPacket = streamDescription.mBytesPerFrame * streamDescription.mChannelsPerFrame;
    // Always should be set to 1
    streamDescription.mFramesPerPacket = 1;
    // Always set to 0, just to be sure
    streamDescription.mReserved = 0;

    //
    // Create the microphone
    //
    self.microphone = [EZMicrophone microphoneWithDelegate:self withAudioStreamBasicDescription: streamDescription];
    
    
    //[self.microphone setAudioStreamBasicDescription: streamDescription];

    

    //
    // Set up the microphone input UIPickerView items to select
    // between different microphone inputs. Here what we're doing behind the hood
    // is enumerating the available inputs provided by the AVAudioSession.
    //
    self.inputs = [EZAudioDevice inputDevices];
    self.microphoneInputPickerView.dataSource = self;
    self.microphoneInputPickerView.delegate = self;

    //
    // Start the microphone
    //
    [self.microphone startFetchingAudio];
    self.microphoneTextLabel.text = @"Microphone On";
    
    // Init the Multimon
    LoggerApp(1, @"Init the multimon");
    
    [self initMultimon];
}

//------------------------------------------------------------------------------
#pragma mark - UIPickerViewDataSource
//------------------------------------------------------------------------------

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

//------------------------------------------------------------------------------

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component
{
    EZAudioDevice *device = self.inputs[row];
    return device.name;
}

//------------------------------------------------------------------------------

- (NSAttributedString *)pickerView:(UIPickerView *)pickerView
             attributedTitleForRow:(NSInteger)row
                      forComponent:(NSInteger)component
{
    EZAudioDevice *device = self.inputs[row];
    UIColor *textColor = [device isEqual:self.microphone.device] ? self.audioPlot.backgroundColor : [UIColor blackColor];
    return  [[NSAttributedString alloc] initWithString:device.name
                                            attributes:@{ NSForegroundColorAttributeName : textColor }];
}

//------------------------------------------------------------------------------

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.inputs.count;
}

//------------------------------------------------------------------------------

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    EZAudioDevice *device = self.inputs[row];
    [self.microphone setDevice:device];
}

//------------------------------------------------------------------------------
#pragma mark - Actions
//------------------------------------------------------------------------------

- (void)changePlotType:(id)sender
{
    NSInteger selectedSegment = [sender selectedSegmentIndex];
    switch (selectedSegment)
    {
        case 0:
            [self drawBufferPlot];
            break;
        case 1:
            [self drawRollingPlot];
            break;
        default:
            break;
    }
}

//------------------------------------------------------------------------------

- (void)toggleMicrophone:(id)sender
{
    BOOL isOn = [sender isOn];
    if (!isOn)
    {
        [self.microphone stopFetchingAudio];
        self.microphoneTextLabel.text = @"Microphone Off";
    }
    else
    {
        [self.microphone startFetchingAudio];
        self.microphoneTextLabel.text = @"Microphone On";
    }
}

//------------------------------------------------------------------------------

- (void)toggleMicrophonePickerView:(id)sender
{
    BOOL isHidden = self.microphoneInputPickerViewTopConstraint.constant != 0.0;
    [self setMicrophonePickerViewHidden:!isHidden];
}

//------------------------------------------------------------------------------

- (void)setMicrophonePickerViewHidden:(BOOL)hidden
{
    CGFloat pickerHeight = CGRectGetHeight(self.microphoneInputPickerView.bounds);
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.55
                          delay:0.0
         usingSpringWithDamping:0.6
          initialSpringVelocity:0.5
                        options:(UIViewAnimationOptionBeginFromCurrentState|
                                 UIViewAnimationOptionCurveEaseInOut|
                                 UIViewAnimationOptionLayoutSubviews)
                     animations:^{
                         weakSelf.microphoneInputPickerViewTopConstraint.constant = hidden ? -pickerHeight : 0.0f;
                         [weakSelf.view layoutSubviews];
                     } completion:nil];
}

//------------------------------------------------------------------------------
#pragma mark - Utility
//------------------------------------------------------------------------------

//
// Give the visualization of the current buffer (this is almost exactly the
// openFrameworks audio input eample)
//
- (void)drawBufferPlot
{
    self.audioPlot.plotType = EZPlotTypeBuffer;
    self.audioPlot.shouldMirror = NO;
    self.audioPlot.shouldFill = NO;
}

//------------------------------------------------------------------------------

//
// Give the classic mirrored, rolling waveform look
//
-(void)drawRollingPlot
{
    self.audioPlot.plotType = EZPlotTypeRolling;
    self.audioPlot.shouldFill = YES;
    self.audioPlot.shouldMirror = YES;
}

#pragma mark - EZMicrophoneDelegate
#warning Thread Safety
//
// Note that any callback that provides streamed audio data (like streaming
// microphone input) happens on a separate audio thread that should not be
// blocked. When we feed audio data into any of the UI components we need to
// explicity create a GCD block on the main thread to properly get the UI
// to work.
//
- (void)microphone:(EZMicrophone *)microphone
  hasAudioReceived:(float **)buffer
    withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels
{
    //
    // Getting audio data as an array of float buffer arrays. What does that mean?
    // Because the audio is coming in as a stereo signal the data is split into
    // a left and right channel. So buffer[0] corresponds to the float* data
    // for the left channel while buffer[1] corresponds to the float* data
    // for the right channel.
    //

    //
    // See the Thread Safety warning above, but in a nutshell these callbacks
    // happen on a separate audio thread. We wrap any UI updating in a GCD block
    // on the main thread to avoid blocking that audio flow.
    //
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        //
        // All the audio plot needs is the buffer data (float*) and the size.
        // Internally the audio plot will handle all the drawing related code,
        // history management, and freeing its own resources.
        // Hence, one badass line of code gets you a pretty plot :)
        //
        [weakSelf.audioPlot updateBuffer:buffer[0] withBufferSize:bufferSize];
        
        
        
//        for (int i = 0; (unsigned int) i <  NUMDEMOD; i++)
//            if (MASK_ISSET(i) && dem[i]->demod)
//            {
//                buffer_t b = {bufferSize, buffer};
//                dem[i]->demod(dem_st+i, b, bufferSize);
//            }
    });
}

//------------------------------------------------------------------------------

- (void)microphone:(EZMicrophone *)microphone hasAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription
{
    //
    // The AudioStreamBasicDescription of the microphone stream. This is useful
    // when configuring the EZRecorder or telling another component what
    // audio format type to expect.
    //
    [EZAudioUtilities printASBD:audioStreamBasicDescription];
}

//------------------------------------------------------------------------------

- (void)microphone:(EZMicrophone *)microphone
     hasBufferList:(AudioBufferList *)buffers //bufferList
    withBufferSize:(UInt32)numFrames // bufferSize
withNumberOfChannels:(UInt32)numberOfChannels
{
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        //
        // Getting audio data as a buffer list that can be directly fed into the
        // EZRecorder or EZOutput. Say whattt...
        //
        if(convertedBuffer == NULL) {
            // Lazy initialization of this buffer is necessary because we don't
            // know the frame count until the first callback
            convertedBuffer = (float*)malloc(sizeof(float) * numFrames);
        }

        SInt16 *inputFrames = (SInt16*)(buffers->mBuffers->mData);

        for(int i = 0; i < numFrames; i++) {
            convertedBuffer[i] = (float)inputFrames[i] / 32768.0f;
        }

        for (int i = 0; (unsigned int) i <  NUMDEMOD; i++)
            if (MASK_ISSET(i) && dem[i]->demod)
            {
                buffer_t b = {inputFrames, convertedBuffer};
                dem[i]->demod(dem_st+i, b, numFrames);
            }

    });
}

//------------------------------------------------------------------------------

- (void)microphone:(EZMicrophone *)microphone changedDevice:(EZAudioDevice *)device
{
    NSLog(@"Microphone changed device: %@", device.name);

    //
    // Called anytime the microphone's device changes
    //
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *name = device.name;
        NSString *tapText = @" (Tap To Change)";
        NSString *microphoneInputToggleButtonText = [NSString stringWithFormat:@"%@%@", device.name, tapText];
        NSRange rangeOfName = [microphoneInputToggleButtonText rangeOfString:name];
        NSMutableAttributedString *microphoneInputToggleButtonAttributedText = [[NSMutableAttributedString alloc] initWithString:microphoneInputToggleButtonText];
        [microphoneInputToggleButtonAttributedText addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:13.0f] range:rangeOfName];
        [weakSelf.microphoneInputToggleButton setAttributedTitle:microphoneInputToggleButtonAttributedText forState:UIControlStateNormal];

        //
        // Reset the device list (a device may have been plugged in/out)
        //
        weakSelf.inputs = [EZAudioDevice inputDevices];
        [weakSelf.microphoneInputPickerView reloadAllComponents];
        [weakSelf setMicrophonePickerViewHidden:YES];
    });
}

- (void)initMultimon {
    int argc; char *argv[20];
    
    int c;
    int errflg = 0;
    int quietflg = 0;
    int i;
    char **itype;
    int mask_first = 1;
    int sample_rate = -1;
    unsigned int overlap = 0;
    char *input_type = "hw";
    
    static struct option long_options[] =
    {
        {"timestamp", no_argument, &timestamp, 1},
        {"label", required_argument, NULL, 'l'},
        {0, 0, 0, 0}
    };
    
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
    if (!quietflg)
        fprintf(stdout, "Enabled demodulators:");
    
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
    NSLog(@">> ready to go");
}


@end
