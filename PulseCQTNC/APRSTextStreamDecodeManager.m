//
//  APRSDecodeManager.m
//  PulseModemA
//
//  Created by Pulsely on 4/10/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "APRSTextStreamDecodeManager.h"

#import "LibfapHelper.h"

@implementation APRSTextStreamDecodeManager
//@synthesize decoder;

+ (id)sharedManager {
    static APRSTextStreamDecodeManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (void)decodeRFAPRS {
    // Set things up
    self.string_buffer = @"";
    self.current_message = @"";

    //dispatch_queue_t myQueue1 = dispatch_queue_create("My Queue 1",NULL);
    dispatch_queue_t myQueue2 = dispatch_queue_create("My Queue 2",NULL);
    
    dispatch_queue_t globalConcurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    dispatch_async( globalConcurrentQueue, ^(void){
        // redirect the stdin
        self.pipe = [NSPipe pipe] ;
        self.pipeHandle = [self.pipe fileHandleForReading];
        dup2([[self.pipe fileHandleForWriting] fileDescriptor], fileno(stdout));
        self.source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, [self.pipeHandle fileDescriptor], 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        dispatch_source_set_event_handler(self.source, ^{
            void* data = malloc(4096);
            ssize_t readResult = 0;
            do {
                errno = 0;
                readResult = read([self.pipeHandle fileDescriptor], data, 4096);
            } while (readResult == -1 && errno == EINTR);
            if (readResult > 0)
            {
                //AppKit UI should only be updated from the main thread
                //dispatch_async(dispatch_get_main_queue(),^{

                dispatch_async(myQueue2, ^{
                    NSString* stdOutString = [[NSString alloc] initWithBytesNoCopy:data length:readResult encoding:NSUTF8StringEncoding freeWhenDone:YES];
                    //NSAttributedString* stdOutAttributedString = [[NSAttributedString alloc] initWithString:stdOutString];
                    //[self.outputTextView.textStorage appendAttributedString:stdOutAttributedString];
                    //LoggerApp(1, @"Output: %@", stdOutString);
                    //printf("%s", data);
                    
                    self.string_buffer = [NSString stringWithFormat: @"%@%@", self.string_buffer, stdOutString];
                    self.current_message = [NSString stringWithFormat: @"%@%@", self.current_message, stdOutString];
                    //self.label.text = self.string_buffer;
                    
                    if ([stdOutString containsString: @"\n"]) {
                        [self processMessage: [self.current_message copy]];
                        self.current_message = @"";
                    }
                });
            }
            else{free(data);}
        });
        dispatch_resume(self.source);
        
        // Init the MultimonHelper
        // Raw decode the wave:
        //     sox -t wav ~/Desktop/projects_tmp/2018-06-21_APRS/samples/aprs.wav -esigned-integer -b16 -r 22050 -t raw - | ~/Desktop/projects_tmp/2018-06-21_APRS/multimon-ng/build/multimon-ng -A --timestamp -
        // Convert sox to raw:
        // sox -t wav ~/Desktop/projects_tmp/2018-06-21_APRS/samples/aprs.wav -esigned-integer -b16 -r 22050 -t raw output.raw
        // Play raw:
        // ~/Desktop/projects_tmp/2018-06-21_APRS/multimon-ng/build/multimon-ng -A --timestamp -t raw output.raw
        // sox aprs.wav --bits 16 -r 22050 --encoding signed-integer --endian little output.raw
        // ~/Desktop/projects_tmp/2018-06-21_APRS/multimon-ng/build/multimon-ng -v 1 -t raw ~/Desktop/projects_tmp/2018-06-21_APRS/multimon-ng/example/ufsk1200.raw

        // Don't run MultimonHelper here
//        self.h = [[MultimonHelper alloc] init];
//        [self.h main_replacement];
    });
}


- (void)processMessage:(NSString *)aprs_message {
    if ([aprs_message hasPrefix: @"APRS: "]) {
        NSString *substring = [aprs_message substringFromIndex: 6];
        
        LibfapHelper *h = [[LibfapHelper alloc] init];
        NSDictionary *payload = [h aprsparsed: substring];
        
        // Post notification over to update stuff
        [[NSNotificationCenter defaultCenter] postNotificationName: NOTIFICATION_NEW_RF_APRS_DICTIONARY object:nil userInfo: @{  @"payload" : payload, @"message" : substring }];

    }
}


@end
