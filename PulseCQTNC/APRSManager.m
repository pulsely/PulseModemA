//
//  APRSManager.m
//  PulseModemA
//
//  Created by Pulsely on 4/6/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "APRSManager.h"
#include "ao.h"
#include <stdint.h>
#include <string.h>
#include <stdarg.h>
#include <unistd.h>
#include "ax25.h"

#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioFile.h>
#import <AudioToolbox/AudioConverter.h>


#import <stdio.h>
#import <stdlib.h>
#import <errno.h>

#import <sys/stat.h>
#import <sys/select.h>
#import <NSLogger/NSLogger.h>
#import "ToCallHelper.h"

@implementation APRSManager
@synthesize someProperty;

+ (id)sharedManager {
    static APRSManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (NSString *)generateAPRS:(NSDictionary *)d packetType:(NSString *)packet_type {
    //NSLog(@"d: %@", d);
    
    ao_device *ao_out;
    ax25_t ax25;

    ax25_init(&ax25, AX25_AFSK1200);
    
    char *src_callsign = NULL;
    char *dst_callsign = NULL;
    
    char *path1 = NULL;
    char *path2 = NULL;

    float latitude, longitude, altitude;
    char slat[5], slng[5];
    char sym_table = '/';
    char sym_code = 'M'; //'O';
    
    char *comment = NULL;
    
    // Used the variable
    src_callsign = [[d objectForKey: @"callsign"]  cStringUsingEncoding: NSUTF8StringEncoding]; //"VR2WOA-4";
    dst_callsign = [[d objectForKey: @"dst_callsign"]  cStringUsingEncoding: NSUTF8StringEncoding]; //"APRS";
    path1 = [[d objectForKey: @"path1"]  cStringUsingEncoding: NSUTF8StringEncoding];
    path2 = [[d objectForKey: @"path2"]  cStringUsingEncoding: NSUTF8StringEncoding];
    
    latitude = [[d objectForKey: @"lat"] doubleValue];
    longitude = [[d objectForKey: @"lon"] doubleValue];
    comment = [[d objectForKey: @"comment"]  UTF8String];
    
    NSString *symbol = [d objectForKey: @"symbol"];
    if (symbol != nil) {
        NSString *s = [[ToCallHelper sharedManager] tocallRepresentation: symbol];
        if ([s length] == 2) {
            sym_table = [s UTF8String][0];
            sym_code = [s UTF8String][1];
        }
    }
    
    altitude = 25.0;
    ax25.samplerate = 42000;
    
    //sym_table
    //sym_code
    
    // setup the code
    /* Setup AO */
    //ao_initialize();

    latitude  = ( 90.0 - latitude) * 380926;
    longitude = (180.0 + longitude) * 190463;
    altitude  = altitude * 3.2808399;

    ax25_base91enc(slat, 4, latitude);
    ax25_base91enc(slng, 4, longitude);
    
    if ([packet_type isEqualToString: @"rf"]) {
        /* Generate the audio tones and send to ao */
        ax25_set_audio_callback(&ax25, &audio_callback, (void *) ao_out);
        
        ax25_frame(
                   &ax25,
                   src_callsign, dst_callsign,
                   path1, path2,
                   //"!%c%s%s%c   /A=%06.0f%s",
                   //sym_table, slat, slng, sym_code, altitude,
                   
                   "!%c%s%s%c   %s",
                   sym_table, slat, slng, sym_code,
                   
                   (comment ? comment : "")
                   );
        
        /* Warn if the sample rate doesn't divide cleanly into the bit rate */
        if(ax25.samplerate % ax25.bitrate != 0) printf("Warning: The sample rate %d does not divide evently into %d. The bit rate will be %.2f\n", ax25.samplerate, ax25.bitrate, (float) ax25.samplerate / (ax25.samplerate / ax25.bitrate));
        return @"RF generated";
    } else {
        NSMutableString *packet = [NSMutableString string];
        [packet appendString: [d objectForKey: @"callsign"]];
        [packet appendString: @">"];
        [packet appendString: [d objectForKey: @"dst_callsign"]];
        [packet appendString: @",TCPIP*"];
        
        // do not generate http://www.aprs-is.net/connecting.aspx
        // Packets originating from the client should only have TCPIP* in the path
//        if ([d objectForKey: @"path1"] != nil) {
//            [packet appendString: @","];
//            if ([d objectForKey: @"path2"] != nil) {
//                // Both path1 and path2 are present
//                [packet appendString: [d objectForKey: @"path1"]];
//                [packet appendString: @","];
//                [packet appendString: [d objectForKey: @"path2"]];
//            } else {
//                // Only path 1
//                [packet appendString: [d objectForKey: @"path1"]];
//            }
//        }
        [packet appendString: @":"];
        
        NSString *compressed = [NSString stringWithFormat: @"!%c%s%s%c   %s", sym_table, slat, slng, sym_code, comment];
        [packet appendString: compressed];
        
        return packet;
    }
}

void audio_callback(void *data, int16_t *wav, size_t wav_len, uint8_t *frame)
{

    NSString *tmp_wav_path_nsstring = [[[NSURL fileURLWithPath: NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent: [NSString stringWithFormat: @"%@.wav", [[NSProcessInfo processInfo] globallyUniqueString]]] path];
    const char *tmp_wav_path = [tmp_wav_path_nsstring cStringUsingEncoding: NSUTF8StringEncoding];
    
    CFStringRef fPath;
    fPath = CFStringCreateWithCString(kCFAllocatorDefault,
                                      tmp_wav_path,
                                      kCFStringEncodingMacRoman);
    OSStatus err;
    
    int mChannels = 1;
    uint_16 totalFramesInFile = wav_len;
    int16_t *outputBuffer = (int16_t *)malloc(sizeof(AudioSampleType) * (totalFramesInFile*mChannels));

    ////////////// Set up Audio Buffer List ////////////
    
    AudioBufferList outputData;
    outputData.mNumberBuffers = 1;
    outputData.mBuffers[0].mNumberChannels = mChannels;
    outputData.mBuffers[0].mDataByteSize = sizeof(AudioSampleType) * totalFramesInFile * mChannels;
    outputData.mBuffers[0].mData = outputBuffer;
    
    AudioSampleType audioFile[ totalFramesInFile * mChannels];

    for (int16_t i = 0;i < totalFramesInFile*mChannels;i++) {
        audioFile[i] = (AudioSampleType)wav[i];
        //printf("i: %d\n", i);
        
        // overflow?
        if ((i > totalFramesInFile -1) ||  (i < 0)) {
            //printf("total number of rames in file: %d\n", totalFramesInFile);

            break;
        }
    }
    
    outputData.mBuffers[0].mData = &audioFile;
    CFURLRef fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,fPath,kCFURLPOSIXPathStyle,false);
    
    ExtAudioFileRef audiofileRef;
    
    // WAVE FILES
    AudioFileTypeID fileType = kAudioFileWAVEType;
    AudioStreamBasicDescription clientFormat;
    clientFormat.mSampleRate = 42000;
    clientFormat.mFormatID = kAudioFormatLinearPCM;
    clientFormat.mFormatFlags = 12; //
    clientFormat.mBitsPerChannel = 16;
    clientFormat.mChannelsPerFrame = mChannels;
    clientFormat.mBytesPerFrame = 2*clientFormat.mChannelsPerFrame;
    clientFormat.mFramesPerPacket = 1;
    clientFormat.mBytesPerPacket = 2*clientFormat.mChannelsPerFrame;
        
    // open the file for writing
    err = ExtAudioFileCreateWithURL((CFURLRef)fileURL, fileType, &clientFormat, NULL, kAudioFileFlags_EraseFile, &audiofileRef);
    if (err != noErr) {
        LoggerApp( 0, @"Problem when creating audio file:");
    }
    
    // tell the ExtAudioFile API what format we'll be sending samples in
    err = ExtAudioFileSetProperty(audiofileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(clientFormat), &clientFormat);
    
    if (err != noErr) {
        LoggerApp( 0, @"Problem setting audio format: ");
    }
    
    UInt32 rFrames = (UInt32)totalFramesInFile;
    // write the data
    err = ExtAudioFileWrite(audiofileRef, rFrames, &outputData);
    
    if (err != noErr)
    {
        LoggerApp( 0, @"Problem writing audio file: ");
    }
    
    // close the file
    ExtAudioFileDispose(audiofileRef);

    [[NSNotificationCenter defaultCenter] postNotificationName: NOTIFICATION_AX25_RESULT object:nil userInfo: @{ @"url" : tmp_wav_path_nsstring }];

    
}



@end
