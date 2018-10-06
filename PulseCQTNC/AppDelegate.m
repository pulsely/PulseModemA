//
//  AppDelegate.m
//  PulseModemA
//
//  Created by Pulsely on 4/6/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "AppDelegate.h"
#import "Chameleon.h"

#import "APRSTextStreamDecodeManager.h"
#import "APRSPositionManager.h"
#import "CtyDat.h"
#import <UICKeyChainStore/UICKeyChainStore.h>
#import "INTULocationManager.h"
#import <RMessage.h>
#import <NSLogger/NSLogger.h>
#import "SettingsTableViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.

    application.idleTimerDisabled = YES;
    
    // Register NSUserdefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults: @{
                                                               NSUSERDEFAULTS_APRS_HOST : @"rotate.aprs2.net",
                                                               NSUSERDEFAULTS_PATH1 : @"WIDE1-1",
                                                               NSUSERDEFAULTS_PATH2 : @"WIDE2-1",
                                                               NSUSERDEFAULTS_DST_CALLSIGN : @"APRS",
                                                               NSUSERDEFAULTS_APRSIS_AUTOCONNECT : [NSNumber numberWithBool: NO],
                                                               NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART : [NSNumber numberWithBool: NO],
                                                               NSUSERDEFAULTS_THEME : @"light",  // TODO: default theme, night mode pending
                                                               NSUSERDEFAULTS_TRANSMIT_APRS_MODE : @"NETWORK",
                                                               NSUSERDEFAULTS_SYMBOL : DEFAULT_USER_SYMBOL,

                                                               }];

    APRSTextStreamDecodeManager *sharedManager = [APRSTextStreamDecodeManager sharedManager];
    [sharedManager decodeRFAPRS];
    
    APRSPositionManager *positionManager = [APRSPositionManager sharedManager];
    [positionManager setup];
    
    CtyDat *ctydat = [CtyDat sharedManager];
    [ctydat loadDXCC];

    //[positionManager connectAction: nil];

    [Chameleon setGlobalThemeUsingPrimaryColor: UIColorFromRGB(0x2e3192) withSecondaryColor: [UIColor clearColor] andContentStyle: UIContentStyleContrast];
    
    
    // Subscrib to location changes
    INTULocationManager *locMgr = [INTULocationManager sharedInstance];
    
//    [locMgr requestLocationWithDesiredAccuracy:INTULocationAccuracyHouse
//                                       timeout:10.0
//                          delayUntilAuthorized:YES    // This parameter is optional, defaults to NO if omitted
//                                         block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
//                                             if (status == INTULocationStatusSuccess) {
//                                                 // Request succeeded, meaning achievedAccuracy is at least the requested accuracy, and
//                                                 // currentLocation contains the device's current location.
//                                                 
//                                                 [[NSNotificationCenter defaultCenter] postNotificationName: NOTIFICATION_INTU_USER_POSITION object:nil userInfo: @{ @"currentLocation" : currentLocation }];
//
//                                             }
//                                             else if (status == INTULocationStatusTimedOut) {
//                                             }
//                                             else {
//
//                                             }
//                                         }];

    [locMgr subscribeToLocationUpdatesWithDesiredAccuracy: INTULocationAccuracyHouse
                                                    block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
                                                        if (status == INTULocationStatusSuccess) {
                                                            
                                                            // A new updated location is available in currentLocation, and achievedAccuracy indicates how accurate this particular location is.
//                                                            [RMessage showNotificationWithTitle: @"Location updated!"
//                                                                                       subtitle: @"Location is only tracked when you are running the app"
//                                                                                           type: RMessageTypeSuccess
//                                                                                 customTypeName:nil
//                                                                                       callback:nil];

                                                            
                                                            [[NSNotificationCenter defaultCenter] postNotificationName: NOTIFICATION_INTU_USER_POSITION object:nil userInfo: @{ @"currentLocation" : currentLocation }];

                                                            [defaults setDouble: currentLocation.coordinate.longitude forKey: NSUSERDEFAULTS_LAST_LONGITUDE];
                                                            [defaults setDouble: currentLocation.coordinate.latitude forKey: NSUSERDEFAULTS_LAST_LATITUDE];
                                                            [defaults synchronize];

                                                        }
                                                        else {
                                                            // An error occurred, more info is available by looking at the specific status returned. The subscription has been kept alive.
//                                                            [RMessage showNotificationWithTitle: @"Location update error"
//                                                                                       subtitle: @"Unable to update your location"
//                                                                                           type: RMessageTypeError
//                                                                                 customTypeName:nil
//                                                                                       callback:nil];

                                                        }
                                                    }];

    NSLocale *currentLocale = [NSLocale currentLocale];  // get the current locale.
    NSString *countryCode = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    
    
    // NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART on start??
    if ( [defaults boolForKey: NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART]) {
        LoggerApp( 0, @"AppDelegate> Modem should be on at launch");
        UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;
        
        [tabBarController setSelectedIndex: 1];
        
        //[tabBarController setSelectedIndex: 0];

    } else {
        LoggerApp( 0, @"AppDelegate> Modem should be off at launch");
    }
    
    NSString *symbol = [defaults objectForKey: NSUSERDEFAULTS_SYMBOL];
    LoggerApp( 0, @"AppDelegate> User Default Symbol is: %@", symbol);
    
    
    return YES;
}


- (void)goToSettings {
    UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;
    [tabBarController setSelectedIndex: 0];
    
    UISplitViewController *s = (UISplitViewController *)[tabBarController selectedViewController];
    UINavigationController *n = (UINavigationController *)[[s viewControllers] objectAtIndex: 0];
    [n popToRootViewControllerAnimated: NO];
    SettingsTableViewController *vc = (SettingsTableViewController *)[n topViewController];
    
    [vc performSegueWithIdentifier: @"settingsSegue" sender: nil];

}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
