//
//  APRSDetailTableViewController.m
//  PulseModemA
//
//  Created by Pulsely on 7/31/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "APRSDetailTableViewController.h"
#import "PulseCQTNC-Swift.h"
#import <NSLogger/NSLogger.h>
#import "CtyDat.h"
#import "ToCallHelper.h"
#import "QRZWebPageViewController.h"
#import "APRSPositionAnnotation.h"
#import "INTULocationManager.h"
@interface APRSDetailTableViewController ()

@end

@implementation APRSDetailTableViewController

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    //[self applyMapViewMemoryFix];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    // update the callsign everytime
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = [NSString stringWithFormat: @"%@",
                  [[self.d objectForKey: @"payload"] objectForKey: @"src_callsign"]];
    
    LoggerApp(0, @"APRSDetailTableViewController> d: %@", self.d );
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 8;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionName;
    switch (section)
    {
        case 0: {
            sectionName = @"Date/Time";
            break;
        }
        case 1: {
            sectionName = @"Detail";
            break;
        }
        case 2: {
            sectionName = @"Comment";
            break;
        }
        case 3: {
            sectionName = @"Map";
            break;
        }
        case 4: {
            sectionName = @"DXCC Area"; // It's named "DXCC Area" for a reason...
            break;
        }
        case 5: {
            sectionName = @"Equipment";
            break;
        }
        case 6: {
            sectionName = @"Action";
            break;
        }
        case 7: {
            sectionName = @"APRS Packet";
            break;
        }
        default: {
            sectionName = @"";
            break;
        }
    }
    return sectionName;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger r;
    switch (section)
    {
        case 0: {
            r = 2;
            break;
        }
        case 1: {
            r = 7;
            break;
        }
        case 2: {
            r = 1;
            break;
        }
        case 3: {
            r = 1;
            break;
        }
        case 4: {
            r = 1;
            break;
        }
        case 5: {
            r = 1;
            break;
        }
        case 6: {
            r = 1;
            break;
        }
        case 7: {
            r = 1;
            break;
        }

        default: {
            r = 1;
            break;
        }
    }
    return r;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    // return fixed width of 300px for map
    if ([indexPath section] == 3) {
        return 300.0;
    }
    return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = [indexPath row];
    NSInteger section = [indexPath section];
    
    static NSString *CellIdentifier;
    UITableViewCell *cell;
    NSDictionary *p = [self.d objectForKey: @"payload"];
    
    switch (section) {
        case 0: {
            CellIdentifier = @"Cell1";
            cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath: indexPath];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            }
            
            if (row == 0) {
                UILabel *label1 = (UILabel *)[cell viewWithTag: 100];
                label1.text = @"UTC";
                
                
                NSString *v = [NSString stringWithFormat: @"%@", [self.d objectForKey: @"datetime"]];
                
                if (v != nil) {
                    UILabel *label2 = (UILabel *)[cell viewWithTag: 101];
                    label2.textColor = UIColorFromRGB( 0x4b529f );
                    label2.text = v;
                }
            }
            if (row == 1) {
                UILabel *label1 = (UILabel *)[cell viewWithTag: 100];
                label1.text = @"Local";
                
                NSString *localDate = [NSDateFormatter localizedStringFromDate: [self.d objectForKey: @"datetime"]
                                                                     dateStyle: NSDateFormatterShortStyle
                                                                     timeStyle: NSDateFormatterShortStyle];

                NSString *v = [NSString stringWithFormat: @"%@", localDate];
                
                if (v != nil) {
                    UILabel *label2 = (UILabel *)[cell viewWithTag: 101];
                    label2.textColor = UIColorFromRGB( 0x4b529f );
                    label2.text = v;
                }
            }

            break;
        }
        case 1: {
            if (row == 6) {
                CellIdentifier = @"Cell6";
            } else {
                CellIdentifier = @"Cell1";
            }
            cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath: indexPath];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            }

            if (row == 0) {
                // callsign
                UILabel *label1 = (UILabel *)[cell viewWithTag: 100];
                label1.text = @"Callsign";
                
                NSString *src_callsign = [p objectForKey: @"src_callsign"];
                
                if (src_callsign != nil) {
                    UILabel *label2 = (UILabel *)[cell viewWithTag: 101];
                    label2.textColor = UIColorFromRGB( 0x4b529f );
                    label2.text = src_callsign;
                }
            }
            if (row == 1) {
                // Destination
                UILabel *label1_1a = (UILabel *)[cell viewWithTag: 100];
                label1_1a.text = @"Destination";
                
                UILabel *label1_1b = (UILabel *)[cell viewWithTag: 101];
                label1_1b.textColor = UIColorFromRGB( 0x4b529f );
                
                if ([p objectForKey: @"dst_callsign"] != nil) {
                    NSString *v = [p objectForKey: @"dst_callsign"];
                    label1_1b.text = v;
                    
                } else {
                    label1_1b.text = @"-";
                }
            }
            if (row == 2) {
                // Destination
                UILabel *label1_1a = (UILabel *)[cell viewWithTag: 100];
                label1_1a.text = @"Path";
                
                UILabel *label1_1b = (UILabel *)[cell viewWithTag: 101];
                label1_1b.textColor = UIColorFromRGB( 0x4b529f );
                
                if ([p objectForKey: @"path"] != nil) {
                    NSString *v = [p objectForKey: @"path"];
                    label1_1b.text = v;
                    
                } else {
                    label1_1b.text = @"-";
                }
            }
            if (row == 3) {
                // Data Source
                UILabel *label1 = (UILabel *)[cell viewWithTag: 100];
                label1.text = @"Data source";
                
                UILabel *label2 = (UILabel *)[cell viewWithTag: 101];
                label2.textColor = UIColorFromRGB( 0x4b529f );
                
                if ([self.d objectForKey: @"source"] != nil) {
                    NSString *v = [self.d objectForKey: @"source"];
                    if ([v isEqualToString: @"feed"]) {
                        label2.text = @"APRS Feed";
                    } else if ([v isEqualToString: @"feed"]) {
                        label2.text = @"Radio Receiver";
                    } else {
                        label2.text = v;
                    }
                    
                } else {
                    label2.text = @"-";
                }
            }
            if (row == 4) {
                // Distance
                UILabel *label1 = (UILabel *)[cell viewWithTag: 100];
                label1.text = @"Distance";
                
                // Figure out the distance
                NSString *v = @"-";

                CLLocationCoordinate2D aprs_location;
                aprs_location.latitude = [[p objectForKey: @"latitude"] doubleValue];
                aprs_location.longitude = [[p objectForKey: @"longitude"]  doubleValue];
                
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                
                double user_lat = [defaults doubleForKey: NSUSERDEFAULTS_LAST_LATITUDE];
                double user_lon = [defaults doubleForKey: NSUSERDEFAULTS_LAST_LONGITUDE];
                
                // Make sure not in the middle of Atlantic, default position
                if ( !((user_lat >= 0.01) && (user_lat <= 0.01))
                    &&
                    !((user_lon >= 0.01) && (user_lon <= 0.01))) {
                    
                    CLLocationCoordinate2D user_location;
                    user_location.latitude = user_lat;
                    user_location.longitude = user_lon;
                    CLLocationDistance distance = MKMetersBetweenMapPoints( MKMapPointForCoordinate(aprs_location),
                                                                           MKMapPointForCoordinate(user_location) );
                    
                    if (distance >= 1000.0) {
                        v = [NSString stringWithFormat: @"%.1f km", (distance/1000.0)];
                    } else {
                        v = [NSString stringWithFormat: @"%.0fm", distance];
                    }
                }
                
                if (v != nil) {
                    UILabel *label2 = (UILabel *)[cell viewWithTag: 101];
                    label2.textColor = UIColorFromRGB( 0x4b529f );
                    label2.text = v;
                } else {
                    UILabel *label2 = (UILabel *)[cell viewWithTag: 101];
                    label2.textColor = UIColorFromRGB( 0x4b529f );
                    label2.text = @"-";
                }
            }
            if (row == 5) {
                // Altitude
                UILabel *label1 = (UILabel *)[cell viewWithTag: 100];
                label1.text = @"Altitude (m)";
                
                NSString *v = [[p objectForKey: @"altitude"] stringValue];
                if (v != nil) {
                    UILabel *label2 = (UILabel *)[cell viewWithTag: 101];
                    label2.textColor = UIColorFromRGB( 0x4b529f );
                    label2.text = v;
                } else {
                    UILabel *label2 = (UILabel *)[cell viewWithTag: 101];
                    label2.textColor = UIColorFromRGB( 0x4b529f );
                    label2.text = @"-";
                }
            }
            if (row == 6) {
                // Icon
                UILabel *label1 = (UILabel *)[cell viewWithTag: 108];
                label1.text = @"Symbol";
                
                UILabel *label2 = (UILabel *)[cell viewWithTag: 109];
                label2.textColor = UIColorFromRGB( 0x4b529f );
                
                if (( [p objectForKey: @"symbol"] != nil ) && ([[p objectForKey: @"symbol"] objectForKey: @"description"] != nil)) {
                    label2.text = [[p objectForKey: @"symbol"] objectForKey: @"description"];
                } else {
                    // Try to show the symbol table and symbol code instead
                    if ( ( [p objectForKey: @"symbol_table"] != nil) &&  ( [p objectForKey: @"symbol_code"] != nil)  ) {
                        label2.text = [NSString stringWithFormat: @"Code: %@, Table: %@", [p objectForKey: @"symbol_code"], [p objectForKey: @"symbol_table"] ];
                    } else {
                        label2.text = @"";
                    }
                }
                
                NSString *file_name = [NSString stringWithFormat: @"aprs-symbols/%@", [[p objectForKey: @"symbol"] objectForKey: @"tocall"]];
                NSString *file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];
                
                UIImageView *v = (UIImageView *)[cell viewWithTag: 110];
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

            break;
        }
        case 2: {
            CellIdentifier = @"Cell2";
            cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath: indexPath];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            }
            
//            UILabel *label3_0 = (UILabel *)[cell viewWithTag: 100];
//            label3_0.text = @"Date/Time";
            
            NSString *comment = [p objectForKey: @"comment"];
            UILabel *label3_0 = (UILabel *)[cell viewWithTag: 102];
            label3_0.textColor = UIColorFromRGB( 0x4b529f );

            if (comment != nil) {
                label3_0.text = comment;
            } else {
                label3_0.text = @"";

            }

            break;
        }
        case 3: {
            CellIdentifier = @"Cell3";
            cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath: indexPath];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            }
            
            MKMapView *m = (MKMapView *)[cell viewWithTag: 104];
            m.delegate = self;
            
            if (([p objectForKey: @"latitude"] != nil) && ([p objectForKey: @"longitude"] != nil)) {
                CLLocationCoordinate2D location;
                location.latitude = [[p objectForKey: @"latitude"] doubleValue];
                location.longitude = [[p objectForKey: @"longitude"]  doubleValue];
                
                MKCoordinateRegion region;
                MKCoordinateSpan span;
                span.latitudeDelta = 1.000;
                span.longitudeDelta = 1.000;
                region.span = span;
                region.center = location;

                m.region = region;
                m.centerCoordinate = location;
                
                // fetch icon filename
                NSString *file_name = [NSString stringWithFormat: @"aprs-symbols/%@", [[p objectForKey: @"symbol"] objectForKey: @"tocall"]];
                NSString *file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];
                if ([[NSFileManager defaultManager] fileExistsAtPath: file_path]) {
                } else {
                    file_name = [NSString stringWithFormat: @"aprs-symbols/%@", @"wildcards"];
                }

                APRSPositionAnnotation *a = [[APRSPositionAnnotation alloc] initWithCoordinate: CLLocationCoordinate2DMake( [[p objectForKey: @"latitude"] doubleValue],
                                                                                                                         [[p objectForKey: @"longitude"] doubleValue]
                                                                                                                         )];
                [a setImageName: file_name];
                    
                //        a.title = [[d objectForKey: @"payload"] objectForKey: @"src_callsign"];
                //        a.subtitle = [[d objectForKey: @"payload"] objectForKey: @"comment"];
                
                [m addAnnotations: @[ a ]];
                
                //            MKCoordinateRegion region;
                //            MKCoordinateSpan span;
                //            span.latitudeDelta = 1.000;
                //            span.longitudeDelta = 1.000;
                //            region.span = span;
                //            region.center = location;
                //            m.region = region;
                //m.centerCoordinate = location;
                
                self.mapView = m;
                
            }
            break;
        }
        case 4: {
//            if (row == 0) {
            CellIdentifier = @"Cell5";
            cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath: indexPath];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            }

            // DXCC: this could be sensitive
            NSString *country_code = [[CtyDat sharedManager] countryareaCodeOfCallSign: [p objectForKey: @"src_callsign"]];
            NSString *country = [[CtyDat sharedManager] countryareaOfCallSign: [p objectForKey: @"src_callsign"]];
            
            // figure out the flag
            NSString *file_name = [NSString stringWithFormat: @"mini-flags/%@", country_code];
            NSString *file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];
            UIImage *i = [UIImage imageNamed: file_path];
            
            UIImageView *v = (UIImageView *)[cell viewWithTag: 106];
            v.image = i;
            
            UILabel *m = (UILabel *)[cell viewWithTag: 107];
            m.textColor = UIColorFromRGB( 0x4b529f );
            
            // Replace "Hong Kong" in CtyDat to "Hong Kong, China"
            if ([country isEqualToString: @"Hong Kong"]) {
                country = @"Hong Kong, China";
            }
            // Replace "Taiwan" in CtyDat to "Taiwan, China"
            if ([country isEqualToString: @"Taiwan"]) {
                country = @"Taiwan, Province of China";
            }
            
            // Replace "Macau" in CtyDat to "Taiwan, China"
            if ([country isEqualToString: @"Macau"]) {
                country = @"Macau, China";
            }
            
            m.text = country;

            break;
        }
        case 5: {
            CellIdentifier = @"Cell2";
            cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath: indexPath];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            }
            
            NSString *tocall = [[ToCallHelper sharedManager] possibleToCall: [p objectForKey: @"dst_callsign"]];
            UILabel *label5_0 = (UILabel *)[cell viewWithTag: 102];
            label5_0.textColor = UIColorFromRGB( 0x4b529f );
            if ((tocall != nil) || ([tocall isEqualToString: @""])) {
                label5_0.text = tocall;
            } else {
                label5_0.text =  @"";
                //label2.textColor = [UIColor whiteColor];
            }
            break;
        }
        case 6: {
            CellIdentifier = @"Cell4";
            cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath: indexPath];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            }
            
            UIButton *button = (UIButton *)[cell viewWithTag: 105];
            
            [button setTitle: @"QRZ.com page" forState: UIControlStateNormal];
            break;
        }
        case 7: {
            CellIdentifier = @"Cell2";
            cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier forIndexPath: indexPath];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            }
            
            //            UILabel *label3_0 = (UILabel *)[cell viewWithTag: 100];
            //            label3_0.text = @"Date/Time";
            
            NSString *message = [self.d objectForKey: @"message"];
            if (message != nil) {
                UILabel *label2 = (UILabel *)[cell viewWithTag: 102];
                label2.textColor = UIColorFromRGB( 0x4b529f );
                label2.text = message;
            }
            break;
        }
        default: {
            cell = nil;
        }
    }
    return cell;
}

#pragma mark - Actions

//- (IBAction)qrzAction:(id)sender {
//}
//
#pragma mark - Mapview delegates

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    static NSString *AnnotationIdentifier = @"Detail_MapView_Annotation";
    
    if ([annotation isKindOfClass:[MKPointAnnotation class]]) {
        MKPinAnnotationView *v1 = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier: @"Pin"];
        v1.pinTintColor = [UIColor greenColor];
        v1.canShowCallout = YES;
        return v1;
    } else if ([annotation isKindOfClass: [APRSPositionAnnotation class]]) {
        APRSPositionAnnotation *a = (APRSPositionAnnotation *) annotation;
        APRSPositionAnnotationView *v2 = [[APRSPositionAnnotationView alloc] initWithAnnotation:annotation
                                                                                    reuseIdentifier: AnnotationIdentifier
                                                                                      withImageName: a.imageName];
        a.annotationView = v2;
        return v2;
    }
    return nil;
}

- (void)applyMapViewMemoryFix {
    if (self.mapView != nil) {
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
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([sender tag] == 105) {
        
        NSString *src_callsign = [[self.d objectForKey: @"payload"] objectForKey: @"src_callsign"];
        if ([[src_callsign componentsSeparatedByString: @"-"] count] == 2) {
            NSString *callsign = [[src_callsign componentsSeparatedByString: @"-"] objectAtIndex: 0];
            
            // Migrate to Swift implementation later
            //WebPageViewController *vc = [segue destinationViewController];
            QRZWebPageViewController *vc = (QRZWebPageViewController *)[segue destinationViewController];
            vc.callsign = callsign;
        }
    }
}

@end
