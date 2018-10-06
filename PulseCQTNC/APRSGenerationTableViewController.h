//
//  APRSGenerationTableViewController.h
//  PulseCQTNC
//
//  Created by Pulsely on 7/30/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "EZAudio/EZAudio.h"
#import <CoreLocation/CoreLocation.h>

@interface APRSGenerationTableViewController : UITableViewController <AVAudioPlayerDelegate> {
    
}

@property (nonatomic, retain) IBOutlet UILabel *callsignLabel;
@property (nonatomic, retain) IBOutlet UIImageView *symbolImageField;

@property (nonatomic, retain) IBOutlet UITextField *dst_callsignTextField;

@property (nonatomic, retain) IBOutlet UITextField *path1TextField;
@property (nonatomic, retain) IBOutlet UITextField *path2TextField;

@property (nonatomic, retain) IBOutlet UITextField *samplerateTextField;
@property (nonatomic, retain) IBOutlet UITextField *latTextField;
@property (nonatomic, retain) IBOutlet UITextField *lonTextField;
@property (nonatomic, retain) IBOutlet UITextField *messageTextField;
@property (nonatomic, retain) IBOutlet UIButton *generateButton;

@property (nonatomic, retain) IBOutlet UISegmentedControl *modeSegmentedControl;

//@property (nonatomic, retain) CLLocation *currentLocation;


@property (strong, nonatomic) AVAudioPlayer *audioPlayer;

@property (nonatomic,weak) IBOutlet EZAudioPlot *audioPlot;

@property (nonatomic, retain) CLLocation *currentUserLocation;


- (IBAction)generateAPRS:(id)sender;
- (void)playWav:(NSString *)url;

- (IBAction)settingScreen:(id)sender;

- (NSString *)symbolOfUser;
- (IBAction)modeAction:(id)sender;

@end
