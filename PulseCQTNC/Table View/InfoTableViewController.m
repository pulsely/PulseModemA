
//
//  InfoTableViewController.m
//  PulseModemA
//
//  Created by Pulsely on 8/8/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "InfoTableViewController.h"
#import "InfoViewController.h"
#import "PulseCQTNC-Swift.h"

@interface InfoTableViewController ()

@end

@implementation InfoTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.contentsArray = [NSMutableArray array];
    
    [self.contentsArray addObject: @{
                                     @"title" : @"Getting started? ⚠️",
                                     @"subtitle" : @"tl;dr guide to PulseModem A",
                                     @"index" : @"1",
                                     @"file_path" : @"www/1_getting_started/index"
                                     }];

//    [self.contentsArray addObject: @{
//                                     @"title" : @"What is APRS 🤷‍♀️",
//                                     @"subtitle" : @"Detailed introduction to APRS",
//                                     @"index" : @"2",
//                                     @"file_path" : @"www/2_what_is_aprs/index"
//                                     }];
//
    [self.contentsArray addObject: @{
                                     @"title" : @"Connecting to APRS-IS 👩‍💻👨🏻‍💻",
                                     @"subtitle" : @"What's up with the callsign and passcode",
                                     @"index" : @"2",
                                     @"file_path" : @"www/3_connecting_to_the_aprsis/index"
                                     }];
    
    [self.contentsArray addObject: @{
                                     @"title" : @"RF operations with your radio ⚡️ 🆒",
                                     @"subtitle" : @"Transmit and receive directly without Internet",
                                     @"index" : @"3",
                                     @"file_path" : @"www/4_rf_operation/index"
                                     }];
    [self.contentsArray addObject: @{
                                     @"title" : @"Roadmap for PulseModem A 🚀",
                                     @"subtitle" : @"This app will be released monthly",
                                     @"index" : @"4",
                                     @"file_path" : @"www/5_roadmap/index"
                                     }];

    [self.contentsArray addObject: @{
                                     @"title" : @"Credits & Acknowledgements 💃🕺",
                                     @"subtitle" : @"Contributions to the PulseModem A",
                                     @"index" : @"A",
                                     @"file_path" : @"www/A_credits/index"
                                     }];
    [self.contentsArray addObject: @{
                                     @"title" : @"License 🖋",
                                     @"subtitle" : @"Essential Legal stuff",
                                     @"index" : @"B",
                                     @"file_path" : @"www/B_license/index"
                                     }];

    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    [comps setDay: 21];
    [comps setMonth: 8];
    [comps setYear: 2018];
    NSDate *approval_date = [[NSCalendar currentCalendar] dateFromComponents:comps];
    
    if( [[NSDate date] timeIntervalSinceDate: approval_date] > 0 ) {
        return [self.contentsArray count];
    } else {
        return [self.contentsArray count] - 1;
    }
    
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell1";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath:indexPath];
    
    NSDictionary *p = [self.contentsArray objectAtIndex: [indexPath row]];
    
    UILabel *titleLabel = (UILabel *)[cell viewWithTag: 101];
    //titleLabel.textColor = UIColorFromRGB( 0x4b529f );
    titleLabel.text = [p objectForKey: @"title"];
    
    UILabel *subtitleLabel = (UILabel *)[cell viewWithTag: 102];
    //subtitleLabel.textColor = UIColorFromRGB( 0x4b529f );
    subtitleLabel.text = [p objectForKey: @"subtitle"];
    
    UILabel *indexLabel = (UILabel *)[cell viewWithTag: 100];
    indexLabel.textColor = UIColorFromRGB( 0x4b529f );
    indexLabel.text = [p objectForKey: @"index"];
    
    return cell;
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

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    
    if (([sender tag] == 50) || ([sender tag] == 51) || [[segue identifier] isEqualToString: @"futureSegue"] ) {
    } else {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
        NSIndexPath *path = [self.tableView indexPathForSelectedRow];
        
        NSDictionary *d = [self.contentsArray objectAtIndex: [path row]];
        
//        UINavigationController *u = (UINavigationController *)segue.destinationViewController;
        ManualViewController *v = (ManualViewController *)segue.destinationViewController; //(InfoViewController *)u.topViewController;
        v.d = d;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
