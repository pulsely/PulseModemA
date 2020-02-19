//
//  APRSTableViewController.m
//  PulseModemA
//
//  Created by Pulsely on 7/29/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "APRSTableViewController.h"
#import "CtyDat.h"
#import "APRSDetailTableViewController.h"
#import <RMessage.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import <NSLogger/NSLogger.h>

@interface APRSTableViewController ()

@end

@implementation APRSTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // hack to make a gear icon
    self.settingButton.title = [NSString stringWithFormat:@" \u2699%C", 0x0000FE0E];// stop unicode to become emoji
    UIFont *customFont = [UIFont fontWithName:@"Avenir" size: 24.0];
    NSDictionary *fontDictionary = @{NSFontAttributeName : customFont};
    [self.settingButton setTitleTextAttributes: fontDictionary forState:UIControlStateNormal];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Serve as the primary TCP connection point, so initialize the 
    self.position_manager = [APRSPositionManager sharedManager];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
    // NOTIFICATION_APRS_POSITIONS_DATA_RELOAD
    // Show a message when disconnect
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector: @selector(reloadPositions:)
                                                 name: NOTIFICATION_APRS_POSITIONS_DATA_RELOAD
                                               object: nil];
    
    // set empty data source
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.tableFooterView = [UIView new];
    
    [self.position_manager addObserver:self forKeyPath:@"connected" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:NULL];
    
    // trigger connect if there's need to autostart
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey: NSUSERDEFAULTS_APRSIS_AUTOCONNECT]) {
        [self connectAction: nil];
    }
}


#pragma mark - DZNEmptyDataSet delegates

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIImage imageNamed:@"sleepycat.png"];
}


- (BOOL)emptyDataSetShouldDisplay:(UIScrollView *)scrollView
{
    return YES;
}


- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    NSString *text;

    if ([self.position_manager connected]) {
        text = @"Waiting for APRS positions";
    } else {
        text = @"Not connected to APRS-IS Network";
    }

    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};

    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView {
    NSString *text;

    if ([self.position_manager connected]) {
        text = @"APRS-IS feed and RF positions will be shown";
    } else {
        text = @"Click 'Connected' if you have entered Callsign and APRS Passcode";
    }

    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;

    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};

    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma mark - Actions


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)reloadPositions:(id)sender {
    /*
     Make sure call with dispatch async or else:
     2018-07-30 02:52:21.171783+0800 PulseCQTNC[33742:2850755] [reports] Main Thread Checker: UI API called on a background thread: -[UITableView reloadData]
     PID: 33742, TID: 2850755, Thread name: (none), Queue name: My Queue 2, QoS: 0
     Backtrace:
     4   PulseCQTNC                          0x00000001045de628 -[APRSTableViewController reloadPositions:] + 88
     5   CoreFoundation                      0x000000010bbaeb8c __CFNOTIFICATIONCENTER_IS_CALLING_OUT_TO_AN_OBSERVER__ + 12
     6   CoreFoundation                      0x000000010bbaea65 _CFXRegistrationPost + 453
     7   CoreFoundation                      0x000000010bbae7a1 ___CFXNotificationPost_block_invoke + 225
     8   CoreFoundation                      0x000000010bb70422 -[_CFXNotificationRegistrar find:object:observer:enumerator:] + 1826
     9   CoreFoundation                      0x000000010bb6f5a1 _CFXNotificationPost + 609
     10  Foundation                          0x000000010a209e57 -[NSNotificationCenter postNotificationName:object:userInfo:] + 66
     11  PulseCQTNC                          0x00000001045dbef6 -[APRSPositionManager addAPRSPosition:source:] + 582
     12  PulseCQTNC                          0x00000001045dbfb0 -[APRSPositionManager addRFTextNotification:] + 112
     13  CoreFoundation                      0x000000010bbaeb8c __CFNOTIFICATIONCENTER_IS_CALLING_OUT_TO_AN_OBSERVER__ + 12
     14  CoreFoundation                      0x000000010bbaea65 _CFXRegistrationPost + 453
     15  CoreFoundation                      0x000000010bbae7a1 ___CFXNotificationPost_block_invoke + 225
     16  CoreFoundation                      0x000000010bb70422 -[_CFXNotificationRegistrar find:object:observer:enumerator:] + 1826
     17  CoreFoundation                      0x000000010bb6f5a1 _CFXNotificationPost + 609
     18  Foundation                          0x000000010a209e57 -[NSNotificationCenter postNotificationName:object:userInfo:] + 66
     19  PulseCQTNC                          0x00000001045be01f -[APRSTextStreamDecodeManager processMessage:] + 383
     20  PulseCQTNC                          0x00000001045bdc37 __43-[APRSTextStreamDecodeManager decodeRFAPRS]_block_invoke_3 + 551
     21  libdispatch.dylib                   0x000000010cf337ab _dispatch_call_block_and_release + 12
     22  libdispatch.dylib                   0x000000010cf347ec _dispatch_client_callout + 8
     23  libdispatch.dylib                   0x000000010cf3cbe5 _dispatch_queue_serial_drain + 1305
     24  libdispatch.dylib                   0x000000010cf3d4fa _dispatch_queue_invoke + 328
     25  libdispatch.dylib                   0x000000010cf4036c _dispatch_root_queue_drain + 664
     26  libdispatch.dylib                   0x000000010cf40076 _dispatch_worker_thread3 + 132
     27  libsystem_pthread.dylib             0x000000010d458169 _pthread_wqthread + 1387
     28  libsystem_pthread.dylib             0x000000010d457be9 start_wqthread + 13

     */
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
        if ([[self.position_manager positions_latest] count] > 0)
        {
            [self.tableView scrollToRowAtIndexPath: [NSIndexPath indexPathForRow: [[self.position_manager positions_latest] count] -1
                                                                       inSection: 0]
                                  atScrollPosition: UITableViewScrollPositionBottom animated:YES];
        }
    });
}


#pragma mark - KVO delegate

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    if ([object connected]) {
        [self.connectButton setTitle: @"Connected"];
    } else {
        [self.connectButton setTitle: @"Disconnected"];
    }
    
    [self.tableView reloadData];
}
#pragma mark - Other actions

- (IBAction)connectAction:(id)sender {
    UICKeyChainStore *keychain = [UICKeyChainStore keyChainStoreWithService: KEY_CHAIN_SERVICE_DOMAIN];
    NSString *callsign = [UICKeyChainStore keyChainStoreWithService: KEY_CHAIN_SERVICE_DOMAIN][KEYCHAIN_CALLSIGN];
    NSString *passcode = [UICKeyChainStore keyChainStoreWithService: KEY_CHAIN_SERVICE_DOMAIN][KEYCHAIN_PASSCODE];
    
    // make sure there are credentials before connecting
    if (( callsign != nil ) && (passcode != nil)) {
        if ([self.position_manager connected]) {
            [self.connectButton setTitle: @"Disconnecting"];
            [self.position_manager disconnectNotificationAction: nil]; // overload notification
        } else {
            
            if ( self.position_manager.tcp_manager.inSocket.isConnected ) {
                [self.position_manager.tcp_manager.inSocket disconnect];
            }
            
            [self.connectButton setTitle: @"Connecting"];
            [self.position_manager connectAction: nil]; // overload notification
        }
    } else {
        [RMessage showNotificationWithTitle: @"No Credentials"
                                   subtitle: @"Enter your callsign and password at Settings"
                                       type: RMessageTypeError
                             customTypeName:nil
                                   callback:nil];
    }
    
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
//#warning Incomplete implementation, return the number of sections
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [ [self.position_manager positions_latest] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80.0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell1";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    NSDictionary *d = [[self.position_manager positions_latest] objectAtIndex:indexPath.row];
    NSDictionary *payload = [d objectForKey: @"payload"];
    
    // build NSMutableAttributedString
    NSMutableAttributedString *callsign_attributed_string = [[NSMutableAttributedString alloc] initWithString: [payload objectForKey: @"src_callsign"]];
    [callsign_attributed_string addAttribute: NSForegroundColorAttributeName value: UIColorFromRGB( 0x4b529f ) range: NSMakeRange( 0, [callsign_attributed_string length] )];
    [callsign_attributed_string addAttribute: NSFontAttributeName
                       value: [UIFont boldSystemFontOfSize:17]
                       range: NSMakeRange( 0, [callsign_attributed_string length] )];
    
    NSMutableAttributedString *separator_attributed_string = [[NSMutableAttributedString alloc] initWithString: @">"];
    [separator_attributed_string addAttribute: NSForegroundColorAttributeName value: [UIColor darkGrayColor] range: NSMakeRange( 0, [separator_attributed_string length] )];

    NSMutableAttributedString *dst_allsign_attributed_string = [[NSMutableAttributedString alloc] initWithString: [payload objectForKey: @"dst_callsign"]];
    [dst_allsign_attributed_string addAttribute: NSForegroundColorAttributeName value: [UIColor darkGrayColor] range: NSMakeRange( 0, [dst_allsign_attributed_string length] )];
    
    [callsign_attributed_string appendAttributedString: separator_attributed_string];
    [callsign_attributed_string appendAttributedString: dst_allsign_attributed_string];
    
    UILabel *src_callsign = (UILabel *)[cell viewWithTag: 100];
    src_callsign.attributedText = callsign_attributed_string;
    //[src_callsign setTextColor: UIColorFromRGB( 0x4b529f )];
    
    UILabel *dst_callsign = (UILabel *)[cell viewWithTag: 101];
    dst_callsign.text = [payload objectForKey: @"path"];

    UILabel *comment = (UILabel *)[cell viewWithTag: 102];
    comment.text = [payload objectForKey: @"comment"];
    
    // Display the DXCC Area flag
    NSString *dxcc_code = [[CtyDat sharedManager] countryareaCodeOfCallSign: [payload objectForKey: @"src_callsign"]];
    NSString *dxcc_file_name = [NSString stringWithFormat: @"mini-flags/%@", dxcc_code];
    
    LoggerApp(0, @"dxcc_file_name: %@", dxcc_file_name);
        
    NSString *dxcc_file_path = [[NSBundle mainBundle] pathForResource: dxcc_file_name ofType:@"png"];
    UIImage *i = [UIImage imageNamed: dxcc_file_path];
    
    UIImageView *imageView = (UIImageView *)[cell viewWithTag: 103];
    imageView.image = i;
    
    // Display the icon
    NSString *file_name = [NSString stringWithFormat: @"aprs-symbols/%@", [[payload objectForKey: @"symbol"] objectForKey: @"tocall"]];
    NSString *file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];
    
    UIImageView *v = (UIImageView *)[cell viewWithTag: 104];
    if ([[NSFileManager defaultManager] fileExistsAtPath: file_path]) {
        UIImage *i = [UIImage imageNamed: file_path];
        v.image = i;
    } else {
        file_name = [NSString stringWithFormat: @"aprs-symbols/%@", @"wildcards"];
        file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];
        UIImage *i = [UIImage imageNamed: file_path];
        v.image = i;
    }
    
    return cell;
}


/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

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


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    
    if (([sender tag] == 50) || ([sender tag] == 51) || [[segue identifier] isEqualToString: @"settingsSegue"] ) {
        // tag == 50 is "settings" button
        // tag == 51 os "raw log" button
    
    } else {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
        NSIndexPath *path = [self.tableView indexPathForSelectedRow];
        
        NSDictionary *d = [[self.position_manager positions_latest] objectAtIndex: [path row]];
        
        UINavigationController *u = (UINavigationController *)segue.destinationViewController;
        APRSDetailTableViewController *v = (APRSDetailTableViewController *)u.topViewController;
        v.d = d;

    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
