//
//  APRSManager.h
//  PulseModemA
//
//  Created by Pulsely on 4/6/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface APRSManager : NSObject

@property (nonatomic, retain) NSString *someProperty;


+ (id)sharedManager;

- (NSString *)generateAPRS:(NSDictionary *)d packetType:(NSString *)packet_type;

@end
