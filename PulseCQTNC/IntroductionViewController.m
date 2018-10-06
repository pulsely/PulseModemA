//
//  IntroductionViewController.m
//  PulseModemA
//
//  Created by Pulsely on 8/2/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "IntroductionViewController.h"
#import "SettingsTableViewController.h"
#import "AppDelegate.h"

@import AVFoundation;
@import Accelerate;


@interface IntroductionViewController ()

@end

@implementation IntroductionViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithBackgroundImage: nil contents:nil];
    if (self) {
//        self.iconSize = 160;
//        self.fontName = @"HelveticaNeue-Thin";
        self.shouldMaskBackground = NO;
        self.shouldBlurBackground = NO;
        //self.hidePageControl = NO;
        self.pageControl.pageIndicatorTintColor = [UIColor whiteColor];
        [self.pageControl setEnabled: YES];
        
        OnboardingContentViewController *firstPage = [[OnboardingContentViewController alloc] initWithTitle: @"Getting Started?"
                                                                                                       body: @"Licensed Amateur Radio operators can send and receive APRS location and message in 2 ways."
                                                                                                      image: nil
                                                                                                 buttonText: nil
                                                                                                     action: nil];
        firstPage.view.backgroundColor = UIColorFromRGB(0x6c74d2);
        
        if ( [(NSString*)[UIDevice currentDevice].model hasPrefix:@"iPad"] ) {
        } else {
            firstPage.topPadding = 0;  // iphone
            firstPage.underIconPadding = 10; // iphone
        }
        firstPage.bottomPadding = 60;

        OnboardingContentViewController *secondPage = [[OnboardingContentViewController alloc] initWithTitle: @"APRS-IS network"
                                                                                                        body: @"Connects APRS radio networks globally by Internet.\nMessages reaching gateways will be relayed to the APRS-IS feed."
                                                                                                       image: nil
                                                                                                  buttonText: nil
                                                                                                      action:nil];
        secondPage.view.backgroundColor = UIColorFromRGB(0x6c74d2);
        if ( [(NSString*)[UIDevice currentDevice].model hasPrefix:@"iPad"] ) {
        } else {
            secondPage.topPadding = 0;  // iphone
            secondPage.underIconPadding = 10; // iphone
        }

        secondPage.bottomPadding = 60;

        OnboardingContentViewController *thirdPage = [[OnboardingContentViewController alloc] initWithTitle: @"Exchange Message via your Radio"
                                                                                                       body: @"Messages sent to local repeaters by RF radio, will relay to APRS"
                                                                                                      image: nil
                                                                                                 buttonText: nil
                                                                                                     action: nil];
        thirdPage.view.backgroundColor = UIColorFromRGB(0x6c74d2);
        if ( [(NSString*)[UIDevice currentDevice].model hasPrefix:@"iPad"] ) {
        } else {
            thirdPage.topPadding = 0;  // iphone
            thirdPage.underIconPadding = 10; // iphone
        }
        
        thirdPage.bottomPadding = 60;
        
        

        
        OnboardingContentViewController *fourthPage = [[OnboardingContentViewController alloc] initWithTitle: @"Setting things up"
                                                                                                        body: @"Now, go to 'settings', and enter your Amateur Radio callsign, and your APRS Passcode"
                                                                                                       image: nil
                                                                                                  buttonText: @"Go to settings"
                                                                                                      action: ^{


                                                                                                          AppDelegate *delegateClass = (AppDelegate*)[[UIApplication sharedApplication] delegate];
                                                                                                          [delegateClass goToSettings];
                                                                                                      }];
        fourthPage.view.backgroundColor = UIColorFromRGB(0x6c74d2);
        if ( [(NSString*)[UIDevice currentDevice].model hasPrefix:@"iPad"] ) {
        } else {
            fourthPage.topPadding = 0;  // iphone
            fourthPage.underIconPadding = 10; // iphone
        }
        fourthPage.bottomPadding = 60;
//        _backgroundImage = [UIImage imageNamed:@"Street"];
//
//        [self onboardWithBackgroundImage: [UIImage imageNamed:@"Street"] ]
        self.viewControllers = @[firstPage, secondPage, thirdPage, fourthPage];
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = @"PulseModem A";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
