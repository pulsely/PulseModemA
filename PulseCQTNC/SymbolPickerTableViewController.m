//
//  SymbolPickerTableViewController.m
//  PulseModemA
//
//  Created by Pulsely on 8/7/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "SymbolPickerTableViewController.h"
#import <NSLogger/NSLogger.h>

@interface SymbolPickerTableViewController ()

@end

@implementation SymbolPickerTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.symbolsMutableArray = [NSMutableArray array];
    
    // Load the symbol JSON
    NSError *error;
    
    NSString* fileContents = [NSString stringWithContentsOfURL: [[NSBundle mainBundle]
                                                                 URLForResource: @"aprs-symbols"
                                                                 withExtension: @"json"]
                                                      encoding: NSUTF8StringEncoding
                                                         error: &error];
    NSDictionary *d = [NSJSONSerialization JSONObjectWithData: [fileContents dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0 error:nil];
    NSDictionary *s = [d objectForKey: @"symbols"];
    
    for(NSString *k in [s allKeys]) {
        NSMutableDictionary *dd = [NSMutableDictionary dictionaryWithDictionary: [s objectForKey: k]];
        [dd setObject: k forKey: @"symbol"];
        
        NSString *desc = [[s objectForKey: k] objectForKey: @"description"];
        
        if (( desc != nil ) && (![desc isEqualToString: @""])) {
            [self.symbolsMutableArray addObject: dd];
        }
    }
    LoggerApp(0, @"self.symbolsMutableArray: %@", self.symbolsMutableArray);

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
    return [self.symbolsMutableArray count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell1";
    
    NSDictionary *p = [self.symbolsMutableArray objectAtIndex: [indexPath row]];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath: indexPath];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    cell.backgroundColor = [UIColor whiteColor];

    // Configure the cell...
    // 100, 101, 102
    UILabel *descriptionLabel = (UILabel *)[cell viewWithTag: 101];
    descriptionLabel.text = [p objectForKey: @"description"];
    
    NSString *file_name = [NSString stringWithFormat: @"aprs-symbols/%@", [p objectForKey: @"tocall"]];
    NSString *file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];
    
    UIImageView *v = (UIImageView *)[cell viewWithTag: 100];
    if ([[NSFileManager defaultManager] fileExistsAtPath: file_path]) {
        UIImage *i = [UIImage imageNamed: file_path];
        v.image = i;
    } else {
        file_name = [NSString stringWithFormat: @"aprs-symbols/%@", @"wildcards"];
        file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];
        UIImage *i = [UIImage imageNamed: file_path];
        v.image = i;
    }
    
    // highlight current row if it's the one
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *current_symbol = [defaults objectForKey: NSUSERDEFAULTS_SYMBOL];
    
    if (current_symbol != nil) {
        if ([current_symbol isEqualToString: [p objectForKey: @"tocall"]]) {
            cell.backgroundColor = [UIColor yellowColor];
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //NSString *tocall = [[self.symbolsMutableArray objectAtIndex: [indexPath row]] objectForKey: @"tocall"];
    NSString *symbol = [[self.symbolsMutableArray objectAtIndex: [indexPath row]] objectForKey: @"symbol"];

    if (symbol != nil) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject: symbol forKey: NSUSERDEFAULTS_SYMBOL];
        [defaults synchronize];
        
        LoggerApp( 0, @"symbol saved: %@", symbol );
        
        [self.navigationController popViewControllerAnimated: YES];
    }
    
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
