//
//  SettingsTableViewController.h
//  PulseModemA
//
//  Created by Pulsely on 7/30/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SettingsTableViewController : UITableViewController <UITextFieldDelegate> {
    
}
@property (nonatomic, retain) IBOutlet UITextField *callsignTextField;
@property (nonatomic, retain) IBOutlet UITextField *passcodeTextField;

@property (nonatomic, retain) IBOutlet UITextField *aprsHostTextField;
@property (nonatomic, retain) IBOutlet UISwitch *autoConnectSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *rfreceiveSwitch;

- (void)saveSettings:(id)sender;

@end
