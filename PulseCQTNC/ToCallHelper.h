//
//  ToCallHelper.h
//  PulseModemA
//
//  Created by Pulsely on 8/2/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ToCallHelper : NSObject {
    
}
@property (nonatomic, retain) NSArray *matching;
@property (nonatomic, retain) NSDictionary *symbols_dict;
@property (nonatomic, retain) NSDictionary *tocalls_dict;

+ (id)sharedManager;
- (void)loadCSV;
- (void)loadSymbols;
- (NSDictionary *)symbolRepresentation:(NSString *)symbol;
- (NSString *)tocallRepresentation:(NSString *)tocall;

- (NSString *)possibleToCall:(NSString *)dst_callsign;

@end
