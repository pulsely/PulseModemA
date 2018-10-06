//
//  APRSPositionAnnotation.h
//  PulseModemA
//
//  Created by Pulsely on 8/7/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import "APRSPositionAnnotationView.h"

@interface APRSPositionAnnotation : NSObject <MKAnnotation>

@property(nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property(nonatomic, weak) APRSPositionAnnotationView *annotationView;

@property(nonatomic, readonly) NSString *imageName;

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *subtitle;

- (id)initWithCoordinate:(CLLocationCoordinate2D)c;
- (void)setCoordinate:(CLLocationCoordinate2D)c;

- (void)setImageName:(NSString *)i;
- (void)setTitle:(NSString *)t;
- (void)setSubtitle:(NSString *)s;

- (void)updateHeading:(float)heading;

@end
