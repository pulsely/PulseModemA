//
//  MapViewController.m
//  PulseModemA
//
//  Created by Pulsely on 7/29/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "MapViewController.h"
#import "APRSPositionManager.h"
#import <NSLogger/NSLogger.h>
#import "INTULocationManager.h"
#import "APRSPositionAnnotation.h"

@interface MapViewController ()

@end

@implementation MapViewController
@synthesize mapView;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.mapView.showsUserLocation = YES;
    self.mapView.delegate = self;
    
    updated_to_new_location = NO;

    
//    self.locationManager = [[CLLocationManager alloc] init];
//    self.locationManager.distanceFilter = kCLDistanceFilterNone;
//    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
//    [self.locationManager startUpdatingLocation];
//    [self.locationManager requestWhenInUseAuthorization];

    // load all the positions to map first
    dispatch_async(dispatch_get_main_queue(), ^{
        self.annotations = [NSMutableArray array];
        APRSPositionManager *m = [APRSPositionManager sharedManager];
        for (NSDictionary *d in m.callsigns_mapkit_array) {
            APRSPositionAnnotation *a = [d objectForKey: @"annotation"];
            
            [self.annotations addObject: a];
        }
        [self.mapView addAnnotations: self.annotations];
    });
    
    // Add any new position directly from NOTIFICATION_NEW_ANNOTATION
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector: @selector(addAPRSPositionToMap:)
                                                name: NOTIFICATION_NEW_ANNOTATION
                                              object: nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    
    // Update the map when user flips to this view
    //[self updateMap: nil];
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    //[self applyMapViewMemoryFix];
}

// update individual positions from notifications
- (void)addAPRSPositionToMap:(NSNotification *)notification {
    
    LoggerApp( 0, @"MapViewController> addAPRSPositionToMap 1: %@", notification);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableDictionary *mutable_payload = [[notification object] objectForKey: @"mutable_payload"];
        
        if (mutable_payload != nil) {
            LoggerApp( 0, @"MapViewController> addAPRSPositionToMap: %@", mutable_payload);

            [self.annotations addObject: [mutable_payload objectForKey: @"annotation"]];
            
            [self.mapView addAnnotation: [mutable_payload objectForKey: @"annotation"]];
//            [self.mapView showAnnotations: self.annotations animated: NO];
        }
    });
}

 // Consider to remove the MapKit upon viewWillDisappear:
 // https://stackoverflow.com/questions/20138419/stop-ios-7-mkmapview-from-leaking-memory#25419783
- (void)applyMapViewMemoryFix {
    
    switch (self.mapView.mapType) {
        case MKMapTypeHybrid:
        {
            self.mapView.mapType = MKMapTypeStandard;
        }
            
            break;
        case MKMapTypeStandard:
        {
            self.mapView.mapType = MKMapTypeHybrid;
        }
            
            break;
        default:
            break;
    }
    self.mapView.showsUserLocation = NO;
    self.mapView.delegate = nil;
    [self.mapView removeFromSuperview];
    self.mapView = nil;
}

#pragma mark - MapKit

- (IBAction)centerUserAction:(id)sender {
    updated_to_new_location = NO;
    
    INTULocationManager *locMgr = [INTULocationManager sharedInstance];
    
    [locMgr requestLocationWithDesiredAccuracy:INTULocationAccuracyHouse
                                       timeout: 10.0
                          delayUntilAuthorized:YES    // This parameter is optional, defaults to NO if omitted
                                         block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
                                             if (status == INTULocationStatusSuccess) {
                                                 // Request succeeded, meaning achievedAccuracy is at least the requested accuracy, and
                                                 // currentLocation contains the device's current location.
                                                 
                                                 [[NSNotificationCenter defaultCenter] postNotificationName: NOTIFICATION_INTU_USER_POSITION object:nil userInfo: @{ @"currentLocation" : currentLocation }];
                                                 self.mapView.centerCoordinate = currentLocation.coordinate;
                                             }
                                             else if (status == INTULocationStatusTimedOut) {
                                             }
                                             else {
                                                 
                                             }
                                         }];

}

- (void)mapView:(MKMapView *)aMapView didUpdateUserLocation:(MKUserLocation *)aUserLocation {
    //LoggerApp( 1, @"MapViewController> didUpdateUserLocation: Update to user new location");
    
    if (!updated_to_new_location) {
        MKCoordinateRegion region;
        MKCoordinateSpan span;
        span.latitudeDelta = 1.000;
        span.longitudeDelta = 1.000;
        CLLocationCoordinate2D location;
        location.latitude = aUserLocation.coordinate.latitude;
        location.longitude = aUserLocation.coordinate.longitude;
        region.span = span;
        region.center = location;
        [aMapView setRegion:region animated:YES];
        
        updated_to_new_location = YES;
    } else {
        //LoggerApp( 1, @"MapViewController> Skipped moving the map too much");
    }
}


//-(void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation{
//    CLLocationCoordinate2D loc = [userLocation coordinate];
//    //放大地图到自身的经纬度位置。
//    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(loc, 250, 250);
//    [self.mapView setRegion:region animated:YES];
//}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id < MKOverlay >)overlay
{
    MKPolylineRenderer *renderer =[[MKPolylineRenderer alloc] initWithPolyline:overlay];
    renderer.strokeColor = [UIColor orangeColor];
    renderer.lineWidth = 2.0;
    
    return renderer;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    
    LoggerApp( 0, @"MapViewController> viewForAnnotation: %@", annotation);

    static NSString *AnnotationIdentifier = @"Detail_MapView_Annotation";
    
    //MKAnnotationView *view =[mapView dequeueReusableAnnotationViewWithIdentifier: AnnotationIdentifier];

    if ([annotation isKindOfClass:[MKPointAnnotation class]]) { // MKPointAnnotation
        MKPinAnnotationView *view = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier: @"Pin"];
        view.pinTintColor = [UIColor greenColor];
        view.canShowCallout = YES;
        return view;
    } else if ([annotation isKindOfClass:[APRSPositionAnnotation class]]) {
        APRSPositionAnnotation *a = (APRSPositionAnnotation *) annotation;
        APRSPositionAnnotationView* view = [[APRSPositionAnnotationView alloc] initWithAnnotation: annotation
                                                                                    reuseIdentifier: AnnotationIdentifier
                                                                                      withImageName: a.imageName];
        a.annotationView = view;
        return view;
    }
    
    return nil;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
