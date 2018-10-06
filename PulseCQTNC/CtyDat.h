//
//  CtyDat.h
//  PulseCQ
//
//  Created by Pulsely on 11/30/16.
//  Copyright © 2016 Pulsely. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CtyDat : NSObject

@property (nonatomic, retain) NSArray *fields;
@property (nonatomic, retain) NSMutableDictionary *dxcc;
@property (nonatomic, retain) NSMutableDictionary *countryareaFlagDict;


@property (nonatomic, retain) NSMutableArray *country_array;

+ (id)sharedManager;
- (void)loadDXCC;
- (NSString *)countryareaOfCallSign:(NSString *)callsign;
- (NSString *)countryareaCodeOfCallSign:(NSString *)callsign;

@end
