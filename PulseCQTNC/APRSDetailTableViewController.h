//
//  APRSDetailTableViewController.h
//  PulseModemA
//
//  Created by Pulsely on 7/31/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface APRSDetailTableViewController : UITableViewController <MKMapViewDelegate> {
    
}

@property (nonatomic, retain) IBOutlet MKMapView *mapView;

@property (nonatomic, retain) NSDictionary *d;

@end
