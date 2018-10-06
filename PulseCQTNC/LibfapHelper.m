//
//  LibfapHelper.m
//  MultimonIOS
//
//  Created by Pulsely on 6/27/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "LibfapHelper.h"
#include "fap.h"
#import "ToCallHelper.h"

@implementation LibfapHelper

- (NSDictionary *)aprsparsed:(NSString *)aprs_message {
    fap_init();
    fap_packet_t *packet = fap_parseaprs( [aprs_message UTF8String], (NSUInteger)[aprs_message length], 0);
    
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if ( packet->error_code )
    {
        char *buffer = "";
        //printf("Failed to parse packet (%s): %d\n", [aprs_message UTF8String], *packet->error_code );
        [d setObject: @"error" forKey: @"parse_flag"];
    } else if ( packet->src_callsign ) {
        if (packet->src_callsign != NULL) {
            [d setObject: [NSString stringWithUTF8String: packet->src_callsign] forKey: @"src_callsign"];
        }
        
        if (packet->dst_callsign != NULL) {
            [d setObject: [NSString stringWithUTF8String: packet->dst_callsign] forKey: @"dst_callsign"];
        }
        
        if (packet->latitude != NULL) {
            [d setObject: [NSNumber numberWithDouble: *packet->latitude] forKey: @"latitude"];
        }

        if (packet->longitude != NULL) {
            [d setObject: [NSNumber numberWithDouble: *packet->longitude] forKey: @"longitude"];
        }
        
        if (packet->altitude != NULL) {
            [d setObject: [NSNumber numberWithDouble: *packet->altitude] forKey: @"altitude"];
        }

        if (packet->message != NULL) {
            [d setObject: [NSString stringWithUTF8String: packet->message] forKey: @"message"];
        }
        
        if (packet->symbol_table != NULL) {
            [d setObject: [NSString stringWithFormat:@"%c" , packet->symbol_table] forKey: @"symbol_table"];
        }
        if (packet->symbol_code != NULL) {
            [d setObject: [NSString stringWithFormat:@"%c" , packet->symbol_code] forKey: @"symbol_code"];
        }
        if ( (packet->symbol_table != NULL) && (packet->symbol_code != NULL)) {
            NSString *symbol = [NSString stringWithFormat:@"%c%c" , packet->symbol_table, packet->symbol_code];
            //NSLog(@"symbol: %@", symbol);
            NSDictionary *r = [[ToCallHelper sharedManager] symbolRepresentation: symbol];
            
            if (r != nil) {
                [d setObject: r forKey: @"symbol"];
            }
        }

        if ((packet->comment != NULL) && (packet->comment != nil)) {
            NSString *comment = [NSString stringWithUTF8String: packet->comment];
            if (comment != nil) {
                [d setObject: comment forKey: @"comment"];
            } else {
                // NSLog(@"APRS: caught nil");
                [d setObject: @"" forKey: @"comment"];
            }
        }
        
        if (packet->path != NULL) {
            //NSLog(@"path: %s", *packet->path);
            
            [d setObject: [NSString stringWithFormat: @"%s", *packet->path] forKey: @"path"];
        }
        
        [d setObject: @"success" forKey: @"parse_flag"];
    }
    fap_free(packet);
    
    fap_cleanup();
    
    return d;
}

@end
