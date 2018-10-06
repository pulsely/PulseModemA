//
//  APRSPositionAnnotation.m
//  PulseModemA
//
//  Created by Pulsely on 8/7/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "APRSPositionAnnotation.h"

@implementation APRSPositionAnnotation

-(id)initWithCoordinate:(CLLocationCoordinate2D)c {
    self = [super init];
    if (self) {
        _coordinate = c;
    }
    return self;
}

- (void)setCoordinate:(CLLocationCoordinate2D)c {
    _coordinate = c;
}

- (void)setImageName:(NSString *)i {
    _imageName = i;
}

- (void)setTitle:(NSString *)t {
    _title = t;
}

- (void)setSubtitle:(NSString *)s {
    _subtitle = s;
}

-(void)updateHeading:(float)heading
{
    if (self.annotationView) {
        [self.annotationView updateHeading:heading];
    }
}


@end
