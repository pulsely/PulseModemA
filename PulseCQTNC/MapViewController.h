//
//  MapViewController.h
//  PulseModemA
//
//  Created by Pulsely on 7/29/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface MapViewController : UIViewController <MKMapViewDelegate> {
    BOOL updated_to_new_location;
}
@property (nonatomic, retain) IBOutlet MKMapView *mapView;
//@property (nonatomic, retain) CLLocationManager *locationManager;

@property (nonatomic, retain) NSMutableArray *annotations;

//- (void)updateMap:(id)sender;
- (void)applyMapViewMemoryFix;

- (IBAction)centerUserAction:(id)sender;

@end
