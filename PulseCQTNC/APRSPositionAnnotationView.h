//
//  APRSPositionAnnotationView.h
//  PulseModemA
//
//  Created by Pulsely on 8/7/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface APRSPositionAnnotationView : MKAnnotationView

- (instancetype)initWithAnnotation:(id <MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier withImageName: (NSString *)imageName;
-(void) updateHeading:(float)heading;

@end
