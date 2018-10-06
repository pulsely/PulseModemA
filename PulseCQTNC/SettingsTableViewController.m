
//
//  SettingsTableViewController.m
//  PulseModemA
//
//  Created by Pulsely on 7/30/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "SettingsTableViewController.h"
#import <NSLogger/NSLogger.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import "ToCallHelper.h"

@interface SettingsTableViewController ()

@end

@implementation SettingsTableViewController
@synthesize callsignTextField, passcodeTextField;

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UICKeyChainStore *keychain = [UICKeyChainStore keyChainStoreWithService: KEY_CHAIN_SERVICE_DOMAIN];
    NSString *callsign = keychain[KEYCHAIN_CALLSIGN];
    NSString *passcode = keychain[KEYCHAIN_PASSCODE];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *aprs_host = [defaults objectForKey: NSUSERDEFAULTS_APRS_HOST];
    if ((aprs_host == nil) || ([aprs_host isEqualToString: @""])) {
        aprs_host = @"rotate.aprs2.net";
    }

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    [self.tableView reloadData];
    UITableViewCell *cell0 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 0 inSection: 0]];
    self.callsignTextField = (UITextField *)[cell0 viewWithTag: 101];
    self.callsignTextField.text = callsign;
    self.callsignTextField.delegate = self;
    self.callsignTextField.tag = 1000;
    self.callsignTextField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    
    UITableViewCell *cell1 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 1 inSection: 0]];
    self.passcodeTextField = (UITextField *)[cell1 viewWithTag: 101];
    self.passcodeTextField.text = passcode;
    self.passcodeTextField.delegate = self;
    self.passcodeTextField.secureTextEntry = YES;
    self.passcodeTextField.tag = 1001;
    self.passcodeTextField.keyboardType = UIKeyboardTypeNumberPad;
    
    UITableViewCell *cell2 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 0 inSection: 1]];
    self.aprsHostTextField = (UITextField *)[cell2 viewWithTag: 101];
    self.aprsHostTextField.text = aprs_host;
    self.aprsHostTextField.delegate = self;
    self.aprsHostTextField.tag = 1002;
    
    
    UITableViewCell *cell3 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 0 inSection: 2]];
    self.autoConnectSwitch = (UISwitch *)[cell3 viewWithTag: 104];
    self.autoConnectSwitch.tag = 1003;
    
    if (self.autoConnectSwitch != nil) {
        if ([defaults boolForKey: NSUSERDEFAULTS_APRSIS_AUTOCONNECT]) {
            [self.autoConnectSwitch setOn: YES];
        } else {
            [self.autoConnectSwitch setOn: NO];
        }
    }
    
    UITableViewCell *cell4 = [self.tableView cellForRowAtIndexPath:  [NSIndexPath indexPathForRow: 1 inSection: 2]];
    self.rfreceiveSwitch = (UISwitch *)[cell4 viewWithTag: 104];
    self.rfreceiveSwitch.tag = 1004;
    
    if (self.rfreceiveSwitch != nil) {
        if ([defaults boolForKey: NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART]) {
            [self.rfreceiveSwitch setOn: YES];
        } else {
            [self.rfreceiveSwitch setOn: NO];
        }
    }
    
    [self.callsignTextField sendActionsForControlEvents: UIControlEventEditingChanged];
    [self.passcodeTextField sendActionsForControlEvents: UIControlEventEditingChanged];
    [self.aprsHostTextField sendActionsForControlEvents: UIControlEventEditingChanged];
    
    [self.callsignTextField addTarget:self action:@selector(saveSettings:) forControlEvents: UIControlEventEditingChanged];
    [self.passcodeTextField addTarget:self action:@selector(saveSettings:) forControlEvents: UIControlEventEditingChanged];
    [self.aprsHostTextField addTarget:self action:@selector(saveSettings:) forControlEvents: UIControlEventEditingChanged];
    
    [self.autoConnectSwitch addTarget:self action:@selector(saveSettings:) forControlEvents: UIControlEventValueChanged];
    [self.rfreceiveSwitch addTarget:self action:@selector(saveSettings:) forControlEvents: UIControlEventValueChanged];

//    [self.aprsHostTextField addTarget:self action:@selector(saveSettings:) forControlEvents: UIControlEventEditingChanged];
//    [self.aprsHostTextField addTarget:self action:@selector(saveSettings:) forControlEvents: UIControlEventEditingChanged];

    self.tableView.alwaysBounceVertical = NO;
    
    self.title = @"Settings";
    
    if ([defaults boolForKey: NSUSERDEFAULTS_APRSIS_AUTOCONNECT]) {
        LoggerApp( 1, @"NSUSERDEFAULTS_APRSIS_AUTOCONNECT: On");
    } else {
        LoggerApp( 1, @"NSUSERDEFAULTS_APRSIS_AUTOCONNECT: Off");
    }
    
    if ([defaults boolForKey: NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART]) {
        LoggerApp( 1, @"NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART: On");
    } else {
        LoggerApp( 1, @"NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART: Off");
    }
    
    LoggerApp( 1, @"representation: %@", [defaults dictionaryRepresentation]);

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)saveSettings:(id)sender {
    LoggerApp( 1, @"SettingsTableViewController> saveSettings");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (( [sender tag] == 1000) || ( [sender tag] == 1001)) { // only handle the events from the 2 UITextFields
        LoggerApp( 1, @"SettingsTableViewController> saveSettings: Save settings triggered: %@", [sender text]);
    
        UICKeyChainStore *keychain = [UICKeyChainStore keyChainStoreWithService: KEY_CHAIN_SERVICE_DOMAIN];
        [keychain setString: self.callsignTextField.text forKey: KEYCHAIN_CALLSIGN];
        [keychain setString: self.passcodeTextField.text forKey: KEYCHAIN_PASSCODE];
        
    } else if (( [sender tag] == 1002) || ( [sender tag] == 1002)) { // only handle the events from the  UITextFields for the APRS Host
        LoggerApp( 1, @"SettingsTableViewController> saveSettings: Save settings triggered: %@", [sender text]);
        
        if ( self.aprsHostTextField.text != nil ) {
            [defaults setObject: self.aprsHostTextField.text forKey: NSUSERDEFAULTS_APRS_HOST];
            [defaults synchronize];
        }
    } else if (( [sender tag] == 1003) || ( [sender tag] == 1004)) {
        LoggerApp( 1, @"SettingsTableViewController> saveSettings: Save settings triggered: %d", [sender tag]);
        
        if ([sender tag] == 1003) {
            [defaults setBool: [sender isOn] forKey: NSUSERDEFAULTS_APRSIS_AUTOCONNECT];
            [defaults synchronize];
        }
        if ([sender tag] == 1004) {
            [defaults setBool: [sender isOn] forKey: NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART]; //setObject: @YES forKey: NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART];
            [defaults synchronize];
        }
    }
    
    
    if ([defaults boolForKey: NSUSERDEFAULTS_APRSIS_AUTOCONNECT] ) {
        LoggerApp( 1, @"NSUSERDEFAULTS_APRSIS_AUTOCONNECT: On");
    } else {
        LoggerApp( 1, @"NSUSERDEFAULTS_APRSIS_AUTOCONNECT: Off");
    }
    
    if ([defaults boolForKey: NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART]) {
        LoggerApp( 1, @"NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART: On");
    } else {
        LoggerApp( 1, @"NSUSERDEFAULTS_RF_RECEIVE_ON_ONSTART: Off");
    }
    
    LoggerApp( 1, @"representation: %@", [defaults dictionaryRepresentation]);
}


#pragma mark - UITextField delegates



- (void)textFieldDidEndEditing:(UITextField *)textField {
    LoggerApp( 1, @"SettingsTableViewController> textFieldDidEndEditing: %@", textField.text);
    //[self saveSettings];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    NSString *sectionName;
    switch (section)
    {
        case 0:
            return 3;
            break;
        case 1:
            return 1;
            break;
        default:
            return 2;
            break;
    }
    return 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
//    if ([indexPath row] < 2) {
//        return 69.0;
//    } else {
//        return 44.0;
//    }
    return 44.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionName;
    switch (section)
    {
        case 0:
            sectionName = @"APRS-IS";
            break;
        case 1:
            sectionName = @"APRS-IS Host";
            break;
        default:
            sectionName = @"Preferences";
            break;
    }
    return sectionName;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Configure the cell...
    if ([indexPath section] == 0) {
        static NSString *CellIdentifier;
        
        if ([indexPath row] == 2) {
            CellIdentifier = @"Cell3";
        } else {
            CellIdentifier = @"Cell1";
        }
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath:indexPath];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: CellIdentifier];
        }
        
        if ([indexPath row] == 0) {
            UILabel *label1 = (UILabel *)[cell viewWithTag:100];
            label1.text = @"Call Sign SSID";
            
            UITextField *textfield1 = (UITextField *)[cell viewWithTag:101];
            textfield1.placeholder = @"VR2TEST-9";
        }
        if ([indexPath row] == 1) {
            UILabel *label2 = (UILabel *)[cell viewWithTag:100];
            label2.text = @"APRS Passcode";
            
            UITextField *textfield2 = (UITextField *)[cell viewWithTag:101];
            textfield2.secureTextEntry = YES;
            textfield2.placeholder = @"";
        }
        if ([indexPath row] == 2) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSString *symbol = [defaults objectForKey: NSUSERDEFAULTS_SYMBOL];
            NSString *symbol_meaning = @"";
            if ( (symbol == nil) || [symbol isEqualToString: @""]) {
                symbol = @"/m";
            }
            NSString *symbol_tocall = @"";
            
            // Translate the symbol to human worded
            if (symbol != nil) {
                NSDictionary *d = [[ToCallHelper sharedManager] symbolRepresentation: symbol];
                symbol_meaning = [d objectForKey: @"description"];
                symbol_tocall = [d objectForKey: @"tocall"];
            }
            
            // Display the icon
            NSString *file_name = [NSString stringWithFormat: @"aprs-symbols/%@", symbol_tocall];
            NSString *file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];

            UILabel *label3 = (UILabel *)[cell viewWithTag:110];
            label3.text = @"Symbol";
            
            UILabel *label4 = (UILabel *)[cell viewWithTag:111];
            label4.text = symbol_meaning;
            
            UIImageView *v = (UIImageView *)[cell viewWithTag:112];
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
    }
    if ([indexPath section] == 1) {
        static NSString *CellIdentifier = @"Cell1";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath:indexPath];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: CellIdentifier];
        }
        
        if ([indexPath row] == 0) {
            UILabel *label1 = (UILabel *)[cell viewWithTag:100];
            label1.text = @"APRS Host";
            
            UITextField *textfield1 = (UITextField *)[cell viewWithTag:101];
            textfield1.placeholder = @"rotate.aprs2.net";
        }
        
        return cell;
    }

    if ([indexPath section] == 2) {
        static NSString *CellIdentifier = @"Cell2";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath:indexPath];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: CellIdentifier];
        }
        
        if ([indexPath row] == 0) {
            UILabel *label3 = (UILabel *)[cell viewWithTag:103];
            label3.text = @"Auto connect to APRS-IS";
            
            UISwitch *switch1 = (UISwitch *)[cell viewWithTag:104];
            //switch1.placeholder = @"rotate.aprs2.net";
        }
        if ([indexPath row] == 1) {
            UILabel *label3 = (UILabel *)[cell viewWithTag:103];
            label3.text = @"RF receive on program launch";
            
            UISwitch *switch1 = (UISwitch *)[cell viewWithTag:104];
        }

        return cell;
    }

    return nil;
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
