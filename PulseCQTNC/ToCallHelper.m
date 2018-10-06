//
//  ToCallHelper.m
//  PulseModemA
//
//  Created by Pulsely on 8/2/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "ToCallHelper.h"
#import <NSLogger/NSLogger.h>

@implementation ToCallHelper
@synthesize matching;

+ (id)sharedManager {
    static ToCallHelper *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (void)loadCSV {
    NSError *error;
    
    NSString* fileContents = [NSString stringWithContentsOfURL: [[NSBundle mainBundle]
                                                                 URLForResource: @"tocalls"
                                                                 withExtension: @"txt"]
                                                      encoding: NSUTF8StringEncoding
                                                         error: &error];
    
    NSArray* rows = [fileContents componentsSeparatedByString:@"\n"];
    
    NSMutableArray *a = [NSMutableArray array];
    for (NSString *row in rows) {
        if (![row hasPrefix: @"//"]) {
            NSArray* c = [row componentsSeparatedByString:@","];
            
            if ([c count] == 2) {
                NSString *k = [c objectAtIndex: 0];
                NSString *v = [c objectAtIndex: 1];
                
                [a addObject: @{ @"k" : k, @"v" : v }];
            }
        }
    }
    self.matching = [a copy];
}

- (void)loadSymbols {
    NSError *error;
    
    NSString* fileContents = [NSString stringWithContentsOfURL: [[NSBundle mainBundle]
                                                                 URLForResource: @"aprs-symbols"
                                                                 withExtension: @"json"]
                                                      encoding: NSUTF8StringEncoding
                                                         error: &error];
    NSDictionary *d = [NSJSONSerialization JSONObjectWithData: [fileContents dataUsingEncoding:NSUTF8StringEncoding]
                                              options:0 error:nil];
    self.symbols_dict = [d objectForKey: @"symbols"];
    self.tocalls_dict = [d objectForKey: @"tocalls"];
}

//   /M to PM
- (NSDictionary *)symbolRepresentation:(NSString *)symbol {
    LoggerApp(0, @"ToCallHelper>> trying to match symbol '%@'", symbol );
    
    if (self.symbols_dict == nil) {
        [self loadSymbols];
    }
    
    if ([self.symbols_dict objectForKey: symbol] != nil) {
        return [self.symbols_dict objectForKey: symbol];
    } else {
        // overwrite point for extra symbols
        if ( [symbol hasSuffix: @"&"] ) {
            LoggerApp(0, @"ToCallHelper>> symbolRepresentation: overwritten with '%@' with '%@'", symbol, [self.symbols_dict objectForKey: @"/&"] );
            return [self.symbols_dict objectForKey: @"/&"];
        }
        
        
        if ( [symbol hasSuffix: @"-"] ) {
            LoggerApp(0, @"ToCallHelper>> symbolRepresentation: overwritten with '%@' with '%@'", symbol, [self.symbols_dict objectForKey: @"\\-"] );
            return [self.symbols_dict objectForKey: @"\\-"];
        }

        // Star
        if ( [symbol hasSuffix: @"#"] ) {
            LoggerApp(0, @"ToCallHelper>> symbolRepresentation: overwritten with '%@' with '%@'", symbol, [self.symbols_dict objectForKey: @"/#"] );
            return [self.symbols_dict objectForKey: @"/#"];
        }
        
        // a
        if ( [symbol hasSuffix: @"a"] ) {
            LoggerApp(0, @"ToCallHelper>> symbolRepresentation: overwritten with '%@' with '%@'", symbol, [self.symbols_dict objectForKey: @"\\a"] );
            return [self.symbols_dict objectForKey: @"\\a"];
        }

        return nil;
    }
}

- (NSString *)possibleToCall:(NSString *)dst_callsign {
    if (self.matching == nil ) {
        [self loadCSV];
    }
    
    NSString *r = @"";
    for (NSDictionary *d in self.matching) {
        if ( [dst_callsign hasPrefix: [d objectForKey: @"k"] ] ) {
            r = [d objectForKey: @"v"];
        }
    }
    return r;
}

//    PM to /m
- (NSString *)tocallRepresentation:(NSString *)tocall {
    if (self.tocalls_dict == nil) {
        [self loadSymbols];
    }
    
    if ([self.tocalls_dict objectForKey: tocall] != nil) {
        return [self.tocalls_dict objectForKey: tocall];
    } else {
        return nil;
    }
}
@end
