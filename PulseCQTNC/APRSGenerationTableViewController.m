//
//  APRSGenerationTableViewController.m
//  PulseModemA
//
//  Created by Pulsely on 7/30/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "APRSGenerationTableViewController.h"
#import "APRSManager.h"
#import <NSLogger/NSLogger.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import "SettingsTableViewController.h"
#import <RMessage.h>
#import "INTULocationManager.h"
#import "ToCallHelper.h"

@interface APRSGenerationTableViewController ()

@end

@implementation APRSGenerationTableViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    //UICKeyChainStore *keychain = [UICKeyChainStore keyChainStoreWithService: KEY_CHAIN_SERVICE_DOMAIN];
    NSString *callsign = [UICKeyChainStore keyChainStoreWithService: KEY_CHAIN_SERVICE_DOMAIN][KEYCHAIN_CALLSIGN];
    
    UITableViewCell *cell0 = [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow: 0 inSection: 0]];
    self.callsignLabel = (UILabel *)[cell0 viewWithTag: 100];
    self.callsignLabel.text = callsign;
    if ((callsign != nil) && (![callsign isEqualToString: @""])) {
        self.callsignLabel.text = callsign;
    } else {
        self.callsignLabel.text = @"🙀 Setup callsign 🙀";
        self.callsignLabel.font = [UIFont systemFontOfSize: 24.0];
    }
    
    // re-display the symbol
    self.symbolImageField = (UIImageView *)[cell0 viewWithTag: 120];
    // Display the icon
    
    
    NSString *symbol = [self symbolOfUser];
    NSString *symbol_tocall = @"";
    // Translate the symbol to human worded
    if (symbol != nil) {
        NSDictionary *d = [[ToCallHelper sharedManager] symbolRepresentation: symbol];
        symbol_tocall = [d objectForKey: @"tocall"];
    }
    
    NSString *file_name = [NSString stringWithFormat: @"aprs-symbols/%@", symbol_tocall];
    NSString *file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath: file_path]) {
        UIImage *i = [UIImage imageNamed: file_path];
        self.symbolImageField.image = i;
    } else {
        file_name = [NSString stringWithFormat: @"aprs-symbols/%@", @"wildcards"];
        file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];
        UIImage *i = [UIImage imageNamed: file_path];
        self.symbolImageField.image = i;
    }
    
    //LoggerApp(0, @"outputs: %@", [EZAudioDevice outputDevices]);
    
    // Force a generation
    INTULocationManager *locMgr = [INTULocationManager sharedInstance];
    
    [locMgr requestLocationWithDesiredAccuracy:INTULocationAccuracyHouse
                                       timeout:10.0
                          delayUntilAuthorized:YES    // This parameter is optional, defaults to NO if omitted
                                         block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
                                             if (status == INTULocationStatusSuccess) {
                                                 // Request succeeded, meaning achievedAccuracy is at least the requested accuracy, and
                                                 // currentLocation contains the device's current location.
                                                 
                                                 [[NSNotificationCenter defaultCenter] postNotificationName: NOTIFICATION_INTU_USER_POSITION object:nil userInfo: @{ @"currentLocation" : currentLocation }];
                                                 
                                             }
                                             else if (status == INTULocationStatusTimedOut) {
                                             }
                                             else {
                                                 
                                             }
                                         }];
    
    // set the default segmented
    if ([[[NSUserDefaults standardUserDefaults] objectForKey: NSUSERDEFAULTS_TRANSMIT_APRS_MODE] isEqualToString: @"rf"]) {
        self.modeSegmentedControl.selectedSegmentIndex = 0;
    } else {
        self.modeSegmentedControl.selectedSegmentIndex = 1;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do these to force the output to headphone
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector: @selector(updateUserPosition:)
                                                 name: NOTIFICATION_INTU_USER_POSITION
                                               object: nil];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    [self.tableView reloadData];
    
    // grab the fields
    
//    UITableViewCell *cell0 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 0 inSection: 0]];
//    self.callsignTextField = (UITextField *)[cell0 viewWithTag: 101];
//    self.callsignTextField.text = @"VR2WOA-3";
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *path1 = [defaults objectForKey: NSUSERDEFAULTS_PATH1];
    NSString *path2 = [defaults objectForKey: NSUSERDEFAULTS_PATH2];
    NSString *dst_callsign = [defaults objectForKey: NSUSERDEFAULTS_DST_CALLSIGN];
    NSString *message = [defaults objectForKey: NSUSERDEFAULTS_MESSAGE_TEXTFIELD];

    UITableViewCell *cell1 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 1 inSection: 0]];
    self.path1TextField = (UITextField *)[cell1 viewWithTag: 101];
    if (path1 != nil) {
        self.path1TextField.text = path1;
    } else {
        self.path1TextField.text = @"WIDE1-1";
    }

    UITableViewCell *cell2 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 2 inSection: 0]];
    self.path2TextField = (UITextField *)[cell2 viewWithTag: 101];
    if (path2 != nil) {
        self.path2TextField.text = path2;
    } else {
        self.path2TextField.text = @"WIDE2-1";
    }

    UITableViewCell *cell3 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 3 inSection: 0]];
    self.dst_callsignTextField = (UITextField *)[cell3 viewWithTag: 101];
    if (dst_callsign != nil) {
        self.dst_callsignTextField.text = dst_callsign;
    } else {
        self.dst_callsignTextField.text = @"APRS";
    }

    UITableViewCell *cell4 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 0 inSection: 2]];
    self.latTextField = (UITextField *)[cell4 viewWithTag: 101];
    self.latTextField.text = @"";
    
    UITableViewCell *cell5 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 1 inSection: 2]];
    self.lonTextField = (UITextField *)[cell5 viewWithTag: 101];
    self.lonTextField.text = @"";
    
    UITableViewCell *cell6 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 0 inSection: 1]];
    self.messageTextField = (UITextField *)[cell6 viewWithTag: 102];
    self.messageTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    if (message != nil) {
        self.messageTextField.text = message;
    } else {
        self.messageTextField.text = @"PulseModem A";
    }
    
    [self.path1TextField sendActionsForControlEvents: UIControlEventEditingChanged];
    [self.path2TextField sendActionsForControlEvents: UIControlEventEditingChanged];
    [self.dst_callsignTextField sendActionsForControlEvents: UIControlEventEditingChanged];
    [self.messageTextField sendActionsForControlEvents: UIControlEventEditingChanged];
    
    [self.path1TextField addTarget:self action:@selector(saveSettings:) forControlEvents: UIControlEventEditingChanged];
    [self.path2TextField addTarget:self action:@selector(saveSettings:) forControlEvents: UIControlEventEditingChanged];
    [self.dst_callsignTextField addTarget:self action:@selector(saveSettings:) forControlEvents: UIControlEventEditingChanged];
    [self.messageTextField addTarget:self action:@selector(saveSettings:) forControlEvents: UIControlEventEditingChanged];
    
   // [self.generateButton setTitleColor: UIColorFromRGB(0x2e3192) forState: UIControlStateNormal];
    [self.generateButton setBackgroundColor: UIColorFromRGB(0x2e3192)];
    [self.generateButton.titleLabel setTextColor: [UIColor whiteColor]];
    
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    [[NSNotificationCenter defaultCenter]
     addObserverForName: NOTIFICATION_AX25_RESULT
     object:nil
     queue:mainQueue
     usingBlock:^(NSNotification *notification)
     {
         NSDictionary *userInfo = notification.userInfo;
         NSString *url = [userInfo objectForKey: @"url"];
         
         //NSLog(@"playWav! %@", url);
         [self playWav: url];
     }];

//    [self addObserver:self forKeyPath:@"currentUserLocation" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:NULL];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)saveSettings:(id)sender {
    LoggerApp( 1, @"SettingsTableViewController> saveSettings: Save settings triggered: %@", [sender text]);
    
    if ( self.path1TextField.text != nil ) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject: self.path1TextField.text forKey: NSUSERDEFAULTS_PATH1];
        [defaults synchronize];
    }
    if ( self.path2TextField.text != nil ) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject: self.path2TextField.text forKey: NSUSERDEFAULTS_PATH2];
        [defaults synchronize];
    }
    if ( self.dst_callsignTextField.text != nil ) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject: self.dst_callsignTextField.text forKey: NSUSERDEFAULTS_DST_CALLSIGN];
        [defaults synchronize];
    }
    if ( self.messageTextField.text != nil ) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject: self.messageTextField.text forKey: NSUSERDEFAULTS_MESSAGE_TEXTFIELD];
        [defaults synchronize];
    }

}

#pragma mark - KVO delegate

- (void)updateUserPosition:(NSNotification *)notification {
    self.currentUserLocation = [[notification userInfo] objectForKey: @"currentLocation"];
    
    //NSLog(@"updateUserPosition....");
    
    //[self.tableView reloadData];
    
    
    
    UITableViewCell *cell4 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 0 inSection: 2]];
    UITextField *latTextField = (UITextField *)[cell4 viewWithTag: 101];
    latTextField.text = [NSString stringWithFormat: @"%lf", self.currentUserLocation.coordinate.latitude];
    
    UITableViewCell *cell5 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 1 inSection: 2]];
    UITextField *lonTextField = (UITextField *)[cell5 viewWithTag: 101];
    lonTextField.text = [NSString stringWithFormat: @"%lf", self.currentUserLocation.coordinate.longitude];
}

/*
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    if (self.currentUserLocation != nil) {
        NSLog(@"location changed....");
    } else {
        
    }
}
 */


#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (([indexPath section] == 0) && ([indexPath row] == 0)) {
        return UITableViewAutomaticDimension;
    } else if (([indexPath section] == 1) && ([indexPath row] == 1)) {
        return 59.0;
    } else {
        return 44.0;
    }
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if (section == 0) {
        return 4;
    } else if (section == 1) {
        return 2;
    } else {
        return 2;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionName;
    switch (section)
    {
        case 0:
            sectionName = @"Callsign & Paths";
            break;
        case 1:
            sectionName = @"Message & Send!";
            break;
        case 2:
            sectionName = @"Your location";
            break;
            //        case 2:
            //            sectionName = @"Passes for next 7 days";
            //            break;
            //        case 3:
            //            sectionName = @"Actions";
            //            break;
        default:
            sectionName = @"";
            break;
    }
    return sectionName;
}


- (void)textFieldDidEndEditing:(UITextField *)textField {
    LoggerApp( 1, @"APRSGenerationTableViewController> textFieldDidEndEditing: %@", textField.text);
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath) {
        NSLog(@"will displaycell");
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = [indexPath row];
    NSInteger section = [indexPath section];
    
    NSString *callsign = [UICKeyChainStore keyChainStoreWithService: KEY_CHAIN_SERVICE_DOMAIN][KEYCHAIN_CALLSIGN];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *path1 = [defaults objectForKey: NSUSERDEFAULTS_PATH1];
    NSString *path2 = [defaults objectForKey: NSUSERDEFAULTS_PATH2];
    NSString *dst_callsign = [defaults objectForKey: NSUSERDEFAULTS_DST_CALLSIGN];
    NSString *message = [defaults objectForKey: NSUSERDEFAULTS_MESSAGE_TEXTFIELD];
    
    
    if (section == 0) {
        if (row == 0) {
            static NSString *CellIdentifier = @"Cell4";
            
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath:indexPath];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: CellIdentifier];
            }
            
            if (row == 0) {
                UILabel *label1 = (UILabel *)[cell viewWithTag:100];
                label1.textColor = UIColorFromRGB(0x2e3192);
                
                if ((callsign != nil) && (![callsign isEqualToString: @""])) {
                    label1.text = callsign;
                } else {
                    label1.text = @"Click to setup callsign";
                }
                
                // Display the icon
                NSString *file_name = [NSString stringWithFormat: @"aprs-symbols/%@", [[ToCallHelper sharedManager] symbolRepresentation: [self symbolOfUser]]];
                NSString *file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];
                
                UIImageView *v = (UIImageView *)[cell viewWithTag: 120];
                if ([[NSFileManager defaultManager] fileExistsAtPath: file_path]) {
                    UIImage *i = [UIImage imageNamed: file_path];
                    v.image = i;
                } else {
                    file_name = [NSString stringWithFormat: @"aprs-symbols/%@", @"wildcards"];
                    file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];
                    UIImage *i = [UIImage imageNamed: file_path];
                    v.image = i;
                }
            }
            
            return cell;
        } else if ((row >= 1) && ( row <= 3 )) {
            static NSString *CellIdentifier = @"Cell1";
            
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath:indexPath];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: CellIdentifier];
            }
            
            if (row == 1) {
                UILabel *label1 = (UILabel *)[cell viewWithTag:100];
                label1.text = @"Path 1";
                
                UITextField *textfield2 = (UITextField *)[cell viewWithTag:101];
                textfield2.placeholder = @"WIDE1-1";
                textfield2.text = path1;
            }
            if (row == 2) {
                UILabel *label1 = (UILabel *)[cell viewWithTag:100];
                label1.text = @"Path 2";
                
                UITextField *textfield3 = (UITextField *)[cell viewWithTag:101];
                textfield3.placeholder = @"WIDE2-1";
                textfield3.text = path2;
            }
            if (row == 3) {
                UILabel *label1 = (UILabel *)[cell viewWithTag:100];
                label1.text = @"Dst Callsign";
                
                UITextField *textfield4 = (UITextField *)[cell viewWithTag:101];
                textfield4.placeholder = @"APRS";
                textfield4.text = dst_callsign;
            }
            
            return cell;
        }
    } else if (section == 1) {
        if (row == 0 ) {
            static NSString *CellIdentifier = @"Cell2";
            
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath:indexPath];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: CellIdentifier];
            }
            
            // Configure the cell...
            UITextField *textfield1 = (UITextField *)[cell viewWithTag:102];
            textfield1.placeholder = @"Your message";
            
            return cell;
        } else if (row == 1 ) {
            static NSString *CellIdentifier = @"Cell3";
            
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath:indexPath];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: CellIdentifier];
            }
            
            // Configure the cell...
            UIButton *button = (UIButton *)[cell viewWithTag:103];
            //button.text = @"Go!";
            self.generateButton = button;
            
            return cell;
        }
    } else if (section == 2) {
        static NSString *CellIdentifier = @"Cell1";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath:indexPath];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: CellIdentifier];
        }
        
        if (row == 0) {
            UILabel *label1 = (UILabel *)[cell viewWithTag:100];
            label1.text = @"Latitude";
            
            UITextField *textfield5 = (UITextField *)[cell viewWithTag:101];
            //self.latTextField = textfield5;

            if (self.currentUserLocation != nil) {
                textfield5.text = [NSString stringWithFormat:@"%lf", self.currentUserLocation.coordinate.latitude];
            } else {
                textfield5.text = @"";
            }
            
        } else {
            UILabel *label1 = (UILabel *)[cell viewWithTag:100];
            label1.text = @"Longitude";
            
            UITextField *textfield6 = (UITextField *)[cell viewWithTag:101];
            //self.lonTextField = textfield6;
            
            if (self.currentUserLocation != nil) {
                textfield6.text = [NSString stringWithFormat:@"%lf", self.currentUserLocation.coordinate.longitude];
            } else {
                textfield6.text = @"";
            }
        }
        
        return cell;
    }
    return nil;
    
}

#pragma mark - Actions

- (void)playWav:(NSString *)url {
    //AVAudioSession *session = [AVAudioSession sharedInstance];
    
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL: [NSURL fileURLWithPath: url] error: nil];
    [self.audioPlayer setDelegate: self];
    [self.audioPlayer prepareToPlay];
    [self.audioPlayer play];
    
    //[self.generateButton setNeedsLayout];
    //[self.generateButton layoutIfNeeded];
    
    // clean up the APRS generate file
    
    //LoggerApp(0, @"wave file: %@", url);
    [[NSFileManager defaultManager] removeItemAtPath: url error:NULL];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}


- (IBAction)generateAPRS:(id)sender {
    if (self.currentUserLocation != nil) {
        APRSManager *sharedManager = [APRSManager sharedManager];
        
        NSString *comment = @"";
        
        if (self.messageTextField.text) {
            comment = self.messageTextField.text;
        }
        
//        UITableViewCell *cell4 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 0 inSection: 2]];
//        UITextField *t1 = (UITextField *)[cell4 viewWithTag: 101];
//
//        UITableViewCell *cell5 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 1 inSection: 2]];
//        UITextField *t2 = (UITextField *)[cell5 viewWithTag: 101];
        NSString *symbolOfUser = [self symbolOfUser]; // should be "/M"
        NSDictionary *symbolRepsentation = [[ToCallHelper sharedManager] symbolRepresentation: [self symbolOfUser]];
        
        NSString *symbol = [symbolRepsentation objectForKey: @"tocall"];
        
        NSDictionary *d = @{
                            @"callsign" : self.callsignLabel.text,
                            @"dst_callsign" : self.dst_callsignTextField.text,
                            @"path1" : self.path1TextField.text,
                            @"path2" : self.path2TextField.text,
                            @"lat" : self.latTextField.text,
                            @"lon" : self.lonTextField.text,
                            //overwrite for demo purposes
//                            @"lat" : @"22.284264",
//                            @"lon" : @"114.162218 ",
                            @"comment" : comment,               // make sure comment is not null
                            @"symbol" : symbol
                            };
        
        LoggerApp(0, @"APRSGenerationTableViewController> generateAPRS: %@", d);
        
        NSString *packet_type;
        
        if (self.modeSegmentedControl.selectedSegmentIndex == 0) {
            packet_type = @"rf";
        } else {
            packet_type = @"tcpip";
        }
        NSString *result = [sharedManager generateAPRS: d packetType: packet_type];
        
        if ([packet_type isEqualToString: @"tcpip"]) {
            UICKeyChainStore *keychain = [UICKeyChainStore keyChainStoreWithService: KEY_CHAIN_SERVICE_DOMAIN];
            NSString *callsign = keychain[KEYCHAIN_CALLSIGN];
            NSString *passcode = keychain[KEYCHAIN_PASSCODE];
            
            if ( (callsign != nil)  && ( passcode != nil )) {
                LoggerApp(0, @"tcpip packet is: %@", result);
                
                // Send the TCP/IP packet via notification?
                [[NSNotificationCenter defaultCenter] postNotificationName: NOTIFICATION_APRS_TCPIP_USER_POSITION
                                                                    object: nil
                                                                  userInfo: @{ @"aprsmessage" : result }];
            } else {
                // Bump user to setup screen
                // Don't enqueue if socket is not connected, too!

                [self settingScreen: nil];

                [RMessage showNotificationWithTitle: @"No credentials"
                                           subtitle: @"Enter your callsign and password"
                                               type: RMessageTypeError
                                     customTypeName:nil
                                           callback:nil];
            }
            

        }
        
        
        [self.messageTextField resignFirstResponder];
    } else {
        [RMessage showNotificationWithTitle: @"Unable to get your current position"
                                   subtitle: @"Please wait until a fix is obtained"
                                       type: RMessageTypeError
                             customTypeName:nil
                                   callback:nil];
    }
    

}

- (IBAction)settingScreen:(id)sender {
    [self.tabBarController setSelectedIndex: 0];
    
    UISplitViewController *s = (UISplitViewController *)[self.tabBarController selectedViewController];
    UINavigationController *n = (UINavigationController *)[[s viewControllers] objectAtIndex: 0];
    [n popToRootViewControllerAnimated: NO];
    SettingsTableViewController *vc = (SettingsTableViewController *)[n topViewController];
    
    [vc performSegueWithIdentifier: @"settingsSegue" sender: nil];
}

- (BOOL)textField:(UITextField *) textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSUInteger oldLength = [textField.text length];
    NSUInteger replacementLength = [string length];
    NSUInteger rangeLength = range.length;
    
    NSUInteger newLength = oldLength - rangeLength + replacementLength;
    
    BOOL returnKey = [string rangeOfString: @"\n"].location != NSNotFound;
    
    return newLength <= APRS_COMMENT_MAXLENGTH || returnKey;
}

#pragma mark - Actions

- (NSString *)symbolOfUser {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *symbol = [defaults objectForKey: NSUSERDEFAULTS_SYMBOL];
    
    if ( (symbol == nil) || [symbol isEqualToString: @""]) {
        symbol = DEFAULT_USER_SYMBOL;
    }
    
    return symbol;
}

- (IBAction)modeAction:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (self.modeSegmentedControl.selectedSegmentIndex == 0) {
        [defaults setObject: @"rf" forKey: NSUSERDEFAULTS_TRANSMIT_APRS_MODE];
        
        
        [RMessage showNotificationWithTitle: @"Transmit mode changed"
                                   subtitle: @"APRS message will be generated and sent via Radio Frequency, through the audio port."
                                       type: RMessageTypeSuccess
                             customTypeName:nil
                                   callback:nil];

    } else {
        [defaults setObject: @"network" forKey: NSUSERDEFAULTS_TRANSMIT_APRS_MODE];
        
        [RMessage showNotificationWithTitle: @"Transmit mode changed"
                                   subtitle: @"APRS message will be sent via the APRS-IS TCP/IP network."
                                       type: RMessageTypeSuccess
                             customTypeName:nil
                                   callback:nil];

    }
    [defaults synchronize];
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
