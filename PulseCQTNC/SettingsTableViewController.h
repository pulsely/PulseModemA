//
//  SettingsTableViewController.h
//  PulseModemA
//
//  Created by Pulsely on 7/30/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "APRSPositionManager.h"

@interface SettingsTableViewController : UITableViewController <UITextFieldDelegate> {
    
}
@property (nonatomic, retain) IBOutlet UITextField *callsignTextField;
@property (nonatomic, retain) IBOutlet UITextField *passcodeTextField;

@property (nonatomic, retain) IBOutlet UITextField *aprsHostTextField;
@property (nonatomic, retain) IBOutlet UISwitch *autoConnectSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *rfreceiveSwitch;


@property (nonatomic, retain) IBOutlet UILabel *passcodeLabel;

- (void)saveSettings:(id)sender;
- (void)clearAPRSPositions:(id)sender;

@end
