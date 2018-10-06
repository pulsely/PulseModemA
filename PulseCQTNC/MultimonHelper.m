//
//  MultimonHelper.m
//  MultimonIOS
//
//  Created by Pulsely on 6/21/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "MultimonHelper.h"

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

//static int verbose_level = 0;
static int repeatable_sox = 0;
static int mute_sox = 0;
static int integer_only = true;
//static bool dont_flush = false;
//static bool is_startline = true;
static int timestamp = 0;
//static char *label = NULL;

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

void process_buffer_raw(float *float_buf, short *short_buf, unsigned int len)
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

static void input_file_raw(unsigned int sample_rate, unsigned int overlap,
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
                    process_buffer_raw(fbuf, buffer, fbuf_cnt-overlap);

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

//
// core audio
//
AudioUnit *audioUnit = NULL;
float *convertedSampleBuffer = NULL;


OSStatus renderCallback(void *userData, AudioUnitRenderActionFlags *actionFlags,
                        const AudioTimeStamp *audioTimeStamp, UInt32 busNumber,
                        UInt32 numFrames, AudioBufferList *buffers) {
    
    //NSLog(@"render...");
    
    OSStatus status = AudioUnitRender(*audioUnit, actionFlags, audioTimeStamp,
                                      1, numFrames, buffers);
    if(status != noErr) {
        return status;
    }
    
    if(convertedSampleBuffer == NULL) {
        // Lazy initialization of this buffer is necessary because we don't
        // know the frame count until the first callback
        convertedSampleBuffer = (float*)malloc(sizeof(float) * numFrames);
    }
    
    SInt16 *inputFrames = (SInt16*)(buffers->mBuffers->mData);
    // NSLog(@"inputFrames: %d", numFrames);
    
    // If your DSP code can use integers, then don't bother converting to
    // floats here, as it just wastes CPU. However, most DSP algorithms rely
    // on floating point, and this is especially true if you are porting a
    // VST/AU to iOS.
    for(int i = 0; i < numFrames; i++) {
        convertedSampleBuffer[i] = (float)inputFrames[i] / 32768.0f;
    }
    
    // process the buffer
    //buffer_t buffer = {short_buf, convertedSampleBuffer};
    
    //NSLog(@"renderCallback> numFrames: %d", numFrames);
    
//    if (fbuf_cnt > overlap) {
//        process_buffer(fbuf, buffer, fbuf_cnt-overlap);
//        memmove(fbuf, fbuf+fbuf_cnt-overlap, overlap*sizeof(fbuf[0]));
//        fbuf_cnt = overlap;
//    }
    //short sbuffer[numFrames];
    
    //NSLog(@"numFrames: %d", numFrames);
    //NSLog(@"NUMDEMOD: %d", NUMDEMOD);
    
    for (int i = 0; (unsigned int) i <  NUMDEMOD; i++)
        if (MASK_ISSET(i) && dem[i]->demod)
        {
            buffer_t b = {inputFrames, convertedSampleBuffer};
            dem[i]->demod(dem_st+i, b, numFrames);
        }
    
        
    // code ends from input_sound
    
    // Now we have floating point sample data from the render callback! We
    // can send it along for further processing, for example:
    // plugin->processReplacing(convertedSampleBuffer, NULL, sampleFrames);
    
    // Assuming that you have processed in place, we can now write the
    // floating point data back to the input buffer.
    for(int i = 0; i < numFrames; i++) {
        // Note that we multiply by 32767 here, NOT 32768. This is to avoid
        // overflow errors (and thus clipping).
        inputFrames[i] = 0; //(SInt16)(convertedSampleBuffer[i] * 32767.0f);
    }

    return noErr;
}



int initAudioSession() {
    audioUnit = (AudioUnit*)malloc(sizeof(AudioUnit));
    
    if(AudioSessionInitialize(NULL, NULL, NULL, NULL) != noErr) {
        return 1;
    }
    
    if(AudioSessionSetActive(true) != noErr) {
        return 1;
    }
    
    UInt32 sessionCategory = kAudioSessionCategory_PlayAndRecord;
    if(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                               sizeof(UInt32), &sessionCategory) != noErr) {
        return 1;
    }
    
    Float32 bufferSizeInSec = 0.2f;
    if(AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration,
                               sizeof(Float32), &bufferSizeInSec) != noErr) {
        return 1;
    }
    
    UInt32 overrideCategory = 1;
    if(AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker,
                               sizeof(UInt32), &overrideCategory) != noErr) {
        return 1;
    }
    
    // There are many properties you might want to provide callback functions for:
    // kAudioSessionProperty_AudioRouteChange
    // kAudioSessionProperty_OverrideCategoryEnableBluetoothInput
    // etc.
    
    return 0;
}

int initAudioStreams(AudioUnit *audioUnit) {
    UInt32 audioCategory = kAudioSessionCategory_PlayAndRecord;
    if(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                               sizeof(UInt32), &audioCategory) != noErr) {
        return 1;
    }
    
    UInt32 overrideCategory = 1;
    if(AudioSessionSetProperty(kAudioSessionOverrideAudioRoute_None,        // was kAudioSessionCategory_PlayAndRecord??
                               sizeof(UInt32), &overrideCategory) != noErr) {
        // Less serious error, but you may want to handle it and bail here
    }
    
    
    AudioComponentDescription componentDescription;
    componentDescription.componentType = kAudioUnitType_Output;
    componentDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    componentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    componentDescription.componentFlags = 0;
    componentDescription.componentFlagsMask = 0;
    AudioComponent component = AudioComponentFindNext(NULL, &componentDescription);
    if(AudioComponentInstanceNew(component, audioUnit) != noErr) {
        return 1;
    }
    
    // enable input https://developer.apple.com/documentation/audiotoolbox/kaudiooutputunitproperty_enableio
    UInt32 enable = 1;
    if(AudioUnitSetProperty(*audioUnit, kAudioOutputUnitProperty_EnableIO,
                            kAudioUnitScope_Input, 1, &enable, sizeof(UInt32)) != noErr) {
        return 1;
    }
    // set max frame to 8192
//    UInt32 maxFramesPerSlice = 8192;
//    int r = AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, sizeof(UInt32));
    
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = renderCallback; // Render function
    callbackStruct.inputProcRefCon = NULL;
    if(AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_SetRenderCallback,
                            kAudioUnitScope_Input, 0, &callbackStruct,
                            sizeof(AURenderCallbackStruct)) != noErr) {
        return 1;
    }
    
    AudioStreamBasicDescription streamDescription;
    // You might want to replace this with a different value, but keep in mind that the
    // iPhone does not support all sample rates. 8kHz, 22kHz, and 44.1kHz should all work.
    streamDescription.mSampleRate = 22050; //44100;
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
    
    // Set up input stream with above properties
    if(AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_StreamFormat,
                            kAudioUnitScope_Input, 0, &streamDescription, sizeof(streamDescription)) != noErr) {
        return 1;
    }
    
    // Ditto for the output stream, which we will be sending the processed audio to
    if(AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_StreamFormat,
                            kAudioUnitScope_Output, 1, &streamDescription, sizeof(streamDescription)) != noErr) {
        return 1;
    }
    
    
//    UInt32 enableOutput        = 0;    // to disable output
//    AudioUnitElement outputBus = 0;
//
//    AudioUnitSetProperty (
//                          *audioUnit,
//                          kAudioOutputUnitProperty_EnableIO,
//                          kAudioUnitScope_Output,
//                          outputBus,
//                          &enableOutput,
//                          sizeof (enableOutput)
//                          );
//
    
    //[[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    
    // fix issue with audio interrupting video recording - allow audio to mix on top of other media
//    UInt32 doSetProperty = 1;
//    
//    UInt32 allowMixing
//    AudioSessionSetProperty (kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof(doSetProperty), &doSetProperty);
//    
//    
//    AudioSessionSetProperty (
//                                       kAudioSessionProperty_OtherMixableAudioShouldDuck,  // 1
//                                       sizeof (allowMixing),                                 // 2
//                                       &allowMixing                                          // 3
//                                       );


    return 0;
}

int startAudioUnit(AudioUnit *audioUnit) {
    if(AudioUnitInitialize(*audioUnit) != noErr) {
        return 1;
    }
    
    if(AudioOutputUnitStart(*audioUnit) != noErr) {
        return 1;
    }
    
    return 0;
}



@implementation MultimonHelper


- (void)input_ios {
    
    int r = initAudioSession();
    NSLog(@"initAudioSession: %d", r );
    
    r = initAudioStreams( audioUnit );
    NSLog(@"initAudioStreams: %d", r );
    
    r = startAudioUnit( audioUnit );
    NSLog(@"startAudioUnit: %d", r );

}

- (void)main_replacement {
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
    //NSLog(@"overlap: %d", overlap);

    // Decide using raw input, or file
    if (ENABLE_AUDIO_TEST_RAW) {
        const char *filename = [[[NSBundle mainBundle] pathForResource: @"output" ofType: @"raw"] cStringUsingEncoding: NSUTF8StringEncoding];
        input_file_raw(sample_rate, overlap, filename, input_type);
    }
    
    [self input_ios];
    
}

@end
