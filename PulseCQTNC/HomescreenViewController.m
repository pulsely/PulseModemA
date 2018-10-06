//
//  ViewController.m
//  MultimonIOS
//
//  Created by Pulsely on 6/21/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "HomescreenViewController.h"
#import "APRSTextStreamDecodeManager.h"
#import "LibfapHelper.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <CoreFoundation/CoreFoundation.h>

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <RMessage.h>

@interface HomescreenViewController ()

@end

@implementation HomescreenViewController
@synthesize textview;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter]    addObserver:    self
                                                selector:    @selector(addTextNotification:)
                                                    name:    NOTIFICATION_NEW_RF_APRS_DICTIONARY
                                                  object:    nil];
    
    APRSTextStreamDecodeManager *m = [[APRSTextStreamDecodeManager alloc] init];
    [m decodeRFAPRS];
    
    self.string_buffer = [[NSMutableAttributedString alloc] initWithString: @""];
    self.textview.attributedText = self.string_buffer;

    // Do a notification on headphone plugged in or not
    [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(audioRouteChangeListenerCallback:)
                                                 name: AVAudioSessionRouteChangeNotification
                                               object: nil];
    [self audioRouteChangeListenerCallback: nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];

}


- (void)addTextNotification:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^(void){
        //dispatch_async(dispatch_get_main_queue(), ^{
        NSString *message = [[notification userInfo] objectForKey: @"message"];
        
        if ([message hasPrefix: @"APRS: "]) {
            message = [message substringFromIndex: 6];
        }
        
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"YYYY-MM-dd\'T\'HH:mm:ssZZZZZ"];
        NSString *date_string = [dateFormat stringFromDate: [NSDate date]];
        
        NSMutableAttributedString *current_time_attributed_string = [[NSMutableAttributedString alloc] initWithString:
                                                                     [NSString stringWithFormat: @"%@\n", date_string]];
        NSRange range = NSMakeRange( 0, [current_time_attributed_string length] - 1);
        [current_time_attributed_string addAttribute:NSForegroundColorAttributeName value: [UIColor yellowColor] range:range];
        
        NSMutableAttributedString *aprs_attributed_string = [[NSMutableAttributedString alloc] initWithString: message];
        range = NSMakeRange( 0, [aprs_attributed_string length] - 1);
        [aprs_attributed_string addAttribute:NSForegroundColorAttributeName value: [UIColor whiteColor] range:range];
        
        [self.string_buffer appendAttributedString: current_time_attributed_string];
        [self.string_buffer appendAttributedString: aprs_attributed_string];
        
        self.textview.attributedText = self.string_buffer;
        
        // scroll to last line
        NSRange lastLine = NSMakeRange(self.textview.text.length - 1, 1);
        [self.textview scrollRangeToVisible: lastLine];
    });

    
    //[self addMessage: message toTextView: self.textview];
}

// TODO: didn't work
//- (void)addMessage: (NSString *)msg toTextView:(UITextView *)textview {
//    __block NSString *message = msg;
//    
//    
//}


- (BOOL)isHeadsetPluggedIn {
    // https://stackoverflow.com/questions/21292586/are-headphones-plugged-in-ios7
    AVAudioSessionRouteDescription* route = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription* desc in [route outputs]) {
        if ([[desc portType] isEqualToString: AVAudioSessionPortHeadphones])
            return YES;
    }
    return NO;
}

- (void)audioRouteChangeListenerCallback:(id)sender {
    if ([self isHeadsetPluggedIn]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [RMessage showNotificationWithTitle: @"Plugged in!"
                                       subtitle: @"You have an audio source from headphone"
                                           type: RMessageTypeSuccess
                                 customTypeName:nil
                                       callback:nil];
        });

        
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{

            [RMessage showNotificationWithTitle: @"Headphone port unplugged"
                                       subtitle: @"APRS Decoding could be unavailable"
                                           type: RMessageTypeError
                                 customTypeName:nil
                                       callback:nil];
        });

    }
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
