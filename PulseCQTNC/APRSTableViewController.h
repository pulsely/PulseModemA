//
//  APRSTableViewController.h
//  PulseModemA
//
//  Created by Pulsely on 7/29/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "APRSPositionManager.h"
#import <DZNEmptyDataSet/UIScrollView+EmptyDataSet.h>

@interface APRSTableViewController : UITableViewController <DZNEmptyDataSetSource, DZNEmptyDataSetDelegate> {
    
}
@property (nonatomic, retain) APRSPositionManager *position_manager;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *settingButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *connectButton;

- (IBAction)connectAction:(id)sender;

- (void)reloadPositions:(id)sender;

@end
