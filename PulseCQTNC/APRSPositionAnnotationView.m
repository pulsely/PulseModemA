//
//  APRSPositionAnnotationView.m
//  PulseModemA
//
//  Created by Pulsely on 8/7/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "APRSPositionAnnotationView.h"

@implementation APRSPositionAnnotationView

- (instancetype)initWithAnnotation:(id <MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier withImageName: (NSString *)imageName
{
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self) {
        self.enabled = YES;
        self.draggable = NO;
        self.canShowCallout = YES;
        self.image = [UIImage imageNamed: imageName];
        
        CGRect frame = CGRectMake(0, 0, 25.0, 25.0);
        [self setFrame:frame];
    }
    
    return self;
}

-(void) updateHeading:(float)heading
{
    self.transform = CGAffineTransformIdentity;
    self.transform = CGAffineTransformMakeRotation(heading);
}

@end
