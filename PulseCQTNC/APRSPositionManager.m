//
//  APRSPositionManager.m
//  PulseModemA
//
//  Created by Pulsely on 7/29/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "APRSPositionManager.h"
#import "LibfapHelper.h"
#import <NSLogger/NSLogger.h>
#import <RMessage.h>
#import <MapKit/MapKit.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import "APRSPositionAnnotation.h"

@implementation APRSPositionManager

+ (id)sharedManager {
    static APRSPositionManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (void)setup {
    self.tcp_manager = [[APRSTCPManager alloc] init];
    self.tcp_manager.delegate = self;
    
    self.positions_array = [NSMutableArray array];
    
    self.flag_login_sent = NO;
    self.connected = NO;
    
    self.telnetSocket = [[GCDAsyncSocket alloc] initWithDelegate: self.tcp_manager delegateQueue:dispatch_get_main_queue()];
    
    

    // Add text from RF
    [[NSNotificationCenter defaultCenter]    addObserver:    self
                                                selector:    @selector(addRFTextNotification:)
                                                    name:    NOTIFICATION_NEW_RF_APRS_DICTIONARY
                                                  object:    nil];
    
    // Handle UIApplicationDidBecomeActive
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(reconnectSocketAction:)
//                                                 name:UIApplicationDidBecomeActiveNotification object:nil];

    // Show a message when disconnect
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector: @selector(disconnectNotificationAction:)
                                                 name: NOTIFICATION_APRSTCP_SOCKET_DISCONNECTED
                                               object: nil];
    

    // init the callsigns arrays
    self.callsigns_mapkit_array = [NSMutableArray array];
    self.callsigns_dict = [NSMutableDictionary dictionary];
    
    // Store messages to be written out
    self.messagesPendingArray = [NSMutableArray array];
    
    // any new messages to pending position write
    [[NSNotificationCenter defaultCenter]    addObserver:    self
                                                selector:    @selector(notificationWriteAPRSPosition:)
                                                    name:    NOTIFICATION_APRS_TCPIP_USER_POSITION
                                                  object:    nil];

}


#pragma mark - Operations

- (void)connectAction:(id)sender {
    if (self.connected) {
        LoggerApp( 0, @"APRSPositionManager> connectAction: disconnecting the socket");
        
        // Disconnect the socket
        if (![self.tcp_manager.inSocket isDisconnected]) {
            [self.tcp_manager disconnect];
        }
        
        //self.connectButton.title = @"Disconnected";
        self.connected = NO;
    } else {
        LoggerApp( 0, @"APRSPositionManager> connectAction: Connecting the socket");
        
        //self.connectButton.title = @"Connecting";
        self.flag_login_sent = NO;
        self.connected = NO;
        
        uint16_t port = 14580; // 10152 or 14580: check ports  http://www.aprs-is.net/javAPRSSrvr/ports.aspx
        NSError *error = nil;
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *aprs_host = [[NSUserDefaults standardUserDefaults] objectForKey: NSUSERDEFAULTS_APRS_HOST];
        
        if ( (aprs_host == nil) || [aprs_host isEqualToString: @""] ) {
            aprs_host = @"rotate.aprs2.net";
        }
        
        // euro.aprs2.net 91.134.209.193 205.233.35.46 rotate.aprs2.net rotate.aprs.net 45.63.21.153 205.233.35.46
        if (![self.telnetSocket connectToHost: aprs_host onPort: port error:&error]) {
            // If there was an error, it's likely something like "already connected" or "no delegate set"
            LoggerApp(1, @"error: %@", error);
            
            
            if (![self.tcp_manager.inSocket isDisconnected]) {
                [self.tcp_manager disconnect];
            }
            
            // a dreaded thing to show, but it has to be done
            NSString *error_message = [NSString stringWithFormat: @"Possibly server issue? Try connect again.\n%@", [error localizedDescription]];
            [RMessage showNotificationWithTitle: @"Unable to connect to APRS-IS"
                                       subtitle: error_message
                                           type: RMessageTypeError
                                 customTypeName:nil
                                       callback:nil];

            return;
        }
    }

}


// Mostly to handle the app waking up
- (void)reconnectSocketAction:(id)sender {
    LoggerApp( 0, @"APRSPositionManager> reconnectSocketAction: %@", sender);
    
    // disconnect the socket no matter what
    if ([self.tcp_manager.inSocket isConnected]) {
        [self.tcp_manager disconnect];
    }
//    self.connectButton.title = @"Reconnecting";
//    connected = NO;
    
    [self connectAction: nil];
}


// Overloaded to handle both notification and button click.
- (void)disconnectNotificationAction:(NSNotification *)notification {
    
    LoggerApp( 0, @"APRSPositionManager> disconnectNotificationAction: %@", notification);
    if (notification != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [RMessage showNotificationWithTitle: @"APRS-IS feed stop"
                                          subtitle: @"Connection to APRS server has been disconnected."
                                               type: RMessageTypeError
                                    customTypeName:nil
                                          callback:nil];
        });
    }
    
    if ([self.tcp_manager.inSocket isConnected]) {
        [self.tcp_manager disconnect];
    }

//    self.connectButton.title = @"Disconnected";
    
    // update the state to no
    self.connected = NO;
    self.flag_login_sent = NO;
}


#pragma mark - Actions

- (void)addAPRSPosition:(NSDictionary *)payload source:(NSString *)source_name {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary: payload];
    
    // only add if it's valid
    if ([[[d objectForKey: @"payload"] objectForKey: @"parse_flag"] isEqualToString: @"success"]) {
        [d setObject: source_name forKey: @"source"];
        [d setObject: [NSDate date] forKey: @"datetime"];
        
        [self.positions_array addObject: d];
        
        LoggerApp( 0, @"APRSPositionManager> addAPRSPosition: %@", payload);
        
        NSDictionary *p = [d objectForKey: @"payload"];
        
        NSString *callsign = [p objectForKey: @"src_callsign"];
        NSString *latitude = [p objectForKey: @"latitude"];
        NSString *longitude = [p objectForKey: @"longitude"];
        
        // fetch icon filename
        NSString *file_name = [NSString stringWithFormat: @"aprs-symbols/%@", [[p objectForKey: @"symbol"] objectForKey: @"tocall"]];
        NSString *file_path = [[NSBundle mainBundle] pathForResource: file_name ofType:@"png"];
        if ([[NSFileManager defaultManager] fileExistsAtPath: file_path]) {
        } else {
            file_name = [NSString stringWithFormat: @"aprs-symbols/%@", @"wildcards"];
        }
        
        APRSPositionAnnotation *annotation = [[APRSPositionAnnotation alloc] initWithCoordinate: CLLocationCoordinate2DMake( [[p objectForKey: @"latitude"] doubleValue],
                                                                                                                          [[p objectForKey: @"longitude"] doubleValue]
                                                                                                                          )];
        [annotation setImageName: file_name];
        
        [annotation setTitle: [[d objectForKey: @"payload"] objectForKey: @"src_callsign"]];
        [annotation setSubtitle: [[d objectForKey: @"payload"] objectForKey: @"comment"]];
        
        NSMutableDictionary *mutable_payload = [NSMutableDictionary dictionaryWithDictionary: payload];
        [mutable_payload setObject: annotation forKey: @"annotation"];
        
        if ((callsign != nil) && (latitude != nil) && (longitude != nil)) {
            //LoggerApp(1, @"callsign: %@ / latitude: %@ / longitude :%@", callsign, latitude, longitude );
            
            if ( [self.callsigns_dict objectForKey: callsign ] == nil) {
                // Callsign dictionary already position, only need to update the coordinate!
                [self.callsigns_dict setObject: mutable_payload forKey: callsign];
                
                // Also push the latest position to array
                [self.callsigns_mapkit_array addObject: mutable_payload];
                
                if (mutable_payload != nil) {
                    [[NSNotificationCenter defaultCenter] postNotificationName: NOTIFICATION_NEW_ANNOTATION
                                                                        object: @{ @"mutable_payload" : mutable_payload }
                                                                      userInfo: nil];
                }
            } else {
                /*
                // Remove the current object from the array, via the dictionary
                [self.callsigns_mapkit_array removeObject: [self.callsigns_dict objectForKey: callsign ]];
                
                // Update the position
                [self.callsigns_dict setObject: mutable_payload forKey: callsign];
                
                // Then set the positions back to the array
                [self.callsigns_mapkit_array addObject: mutable_payload];
                 */
                
                // Only needs to update the current payload
                NSMutableDictionary *md = [self.callsigns_dict objectForKey: callsign ];
                APRSPositionAnnotation *a = [md objectForKey: @"annotation"];
                [a setCoordinate: annotation.coordinate];
                a.title = annotation.title;
                a.subtitle = annotation.subtitle;
            }
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName: NOTIFICATION_APRS_POSITIONS_DATA_RELOAD
                                                            object: @{ @"mutable_payload" : mutable_payload }
                                                          userInfo: nil];
    }
}

- (void)addRFTextNotification:(NSNotification *)notification {
    [self addAPRSPosition: [notification userInfo] source: APRS_DATA_SOURCE_RF];
    /*
    dispatch_async(dispatch_get_main_queue(), ^(void){
        //dispatch_async(dispatch_get_main_queue(), ^{
        NSString *message = [[notification userInfo] objectForKey: @"message"];
        
        if ([message hasPrefix: @"APRS: "]) {
            message = [message substringFromIndex: 6];
        }
        
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"YYYY-MM-dd\'T\'HH:mm:ssZZZZZ"];
        NSString *date_string = [dateFormat stringFromDate: [NSDate date]];
        
        NSMutableAttributedString *current_time_attributed_string = [[NSMutableAttributedString alloc] initWithString:
                                                                     [NSString stringWithFormat: @"%@\n", date_string]];
        NSRange range = NSMakeRange( 0, [current_time_attributed_string length] - 1);
        [current_time_attributed_string addAttribute:NSForegroundColorAttributeName value: [UIColor yellowColor] range:range];
        
        NSMutableAttributedString *aprs_attributed_string = [[NSMutableAttributedString alloc] initWithString: message];
        range = NSMakeRange( 0, [aprs_attributed_string length] - 1);
        [aprs_attributed_string addAttribute:NSForegroundColorAttributeName value: [UIColor redColor] range:range];
        
        [self.string_buffer appendAttributedString: current_time_attributed_string];
        [self.string_buffer appendAttributedString: aprs_attributed_string];
        
        self.textview.attributedText = self.string_buffer;
        
        // scroll to last line
        NSRange lastLine = NSMakeRange(self.textview.text.length - 1, 1);
        [self.textview scrollRangeToVisible: lastLine];
    });
    //[self addMessage: message toTextView: self.textview];
     */
}

#pragma mark - Delegates


- (void) telnetManager:(APRSTCPManager *)manager didReceiveData:(NSData *)data {
    //self.connectButton.title = @"Connected";
    self.connected = YES;
    
    NSString *aprs_message = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];
    
    NSLog(@"aprs_message: %@", aprs_message);
    if (![aprs_message hasPrefix: @"#"]) {
        //[self addMessage: incoming textView: self.textview];
        LibfapHelper *h = [[LibfapHelper alloc] init];
        
        // count how many \n
        NSArray *a = [aprs_message componentsSeparatedByString: @"\n"];
        if ([a count] > 1) {
            for (NSString *s in a) {
                if ((s == nil) && ([s isEqualToString: @""])) {
                    NSLog(@"aprs_message: %@ %@", s, @" (contains \n)");
                } else {
                    NSLog(@"aprs_message: %@", s);
                    NSDictionary *payload = [h aprsparsed: [s stringByTrimmingCharactersInSet: [NSCharacterSet newlineCharacterSet]]];
                    
                    [self addAPRSPosition: @{  @"payload" : payload, @"message" : aprs_message } source: APRS_DATA_SOURCE_FEED];
                }
            }
        } else {
            // removed the enter key at the end
            aprs_message = [aprs_message stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            
            if ((aprs_message != nil) && (![aprs_message isEqualToString: @""])) {
                NSDictionary *payload = [h aprsparsed: aprs_message];
                
                [self addAPRSPosition: @{  @"payload" : payload, @"message" : aprs_message } source: APRS_DATA_SOURCE_FEED];
            }

        }
    }
    
    if ([aprs_message hasPrefix: @"#"]) {
        if (1) { // }!self.flag_login_sent) {
            
            UICKeyChainStore *keychain = [UICKeyChainStore keyChainStoreWithService: KEY_CHAIN_SERVICE_DOMAIN];
            NSString *callsign = keychain[KEYCHAIN_CALLSIGN];
            NSString *passcode = keychain[KEYCHAIN_PASSCODE];
            
            if ( (callsign != nil) && (passcode != nil)) {
                self.flag_login_sent = YES;
                [self.tcp_manager sendLogin: nil];
            } else {
                [RMessage showNotificationWithTitle: @"No credentials"
                                           subtitle: @"Enter your callsign and password"
                                               type: RMessageTypeError
                                     customTypeName:nil
                                           callback:nil];
            }
        }
    }
    
    if ([aprs_message hasPrefix: @"# logresp"]) {
        if ([aprs_message rangeOfString: @" verified" options:NSCaseInsensitiveSearch].location == NSNotFound) {
        } else {
            // user is likely verified
            //        [[NSNotificationCenter defaultCenter] postNotificationName: NOTIFICATION_USER_VERIFIED
            //                                                            object: nil
            //                                                          userInfo: @{ @"msg" : aprs_message }];
            
            [RMessage showNotificationWithTitle: @"You are verified"
                                       subtitle: aprs_message //@"You will receieve APRS-IS feed update"
                                           type: RMessageTypeSuccess
                                 customTypeName:nil
                                       callback:nil];
        }
        
        if ([aprs_message rangeOfString:@"unverified" options:NSCaseInsensitiveSearch].location == NSNotFound) {
        } else {
            // user is likely unverified
            //        [[NSNotificationCenter defaultCenter] postNotificationName: NOTIFICATION_USER_UNVERIFIED
            //                                                            object: nil
            //                                                          userInfo: @{ @"msg" : aprs_message }];
            
            [RMessage showNotificationWithTitle: @"You are not verified"
                                       subtitle: @"You may not post to APRS-IS network over TCP/IP"
                                           type: RMessageTypeError
                                 customTypeName:nil
                                       callback:nil];
        }
    } else if ([aprs_message hasPrefix: @"# Port full"]) {
        [RMessage showNotificationWithTitle: @"Port Full"
                                   subtitle: @"Connection to APRS server is full"
                                       type: RMessageTypeError
                             customTypeName:nil
                                   callback:nil];
    }
    
    // write the messages if there are responses, in case the socket isn't connected before at notificationWriteAPRSPosition:
    [self writeMessages];
}

#pragma mark - Get/Setters

- (NSMutableArray *)positions_latest {
    return self.positions_array;
}

- (void)notificationWriteAPRSPosition:(NSNotification *)notification {
    NSString *m = [NSString stringWithFormat: @"%@\r\n", [[notification userInfo] objectForKey: @"aprsmessage"]];
    LoggerApp(0, @"TESTING0> aprs_message: %@", m);
    
    if ([self.tcp_manager.inSocket isConnected]) {
        // enqueue to pending array
        [self.messagesPendingArray addObject: m];
        
        [self writeMessages];
    } else {
        // Don't enqueue if socket is not connected
        [RMessage showNotificationWithTitle: @"APRS-IS not connected"
                                   subtitle: @"Position not sent"
                                       type: RMessageTypeError
                             customTypeName:nil
                                   callback:nil];
    }
}

#pragma mark - Send the pending messages out to socket

- (void)writeMessages {
    if ([self.tcp_manager.inSocket isConnected]) {
        if ([self.messagesPendingArray count] > 0) {
            for (NSString *s in self.messagesPendingArray) {
                [RMessage showNotificationWithTitle: @"Network message sent"
                                           subtitle: s
                                               type: RMessageTypeSuccess
                                     customTypeName:nil
                                           callback:nil];

                [self.tcp_manager socketWriteString: s];
                [self.messagesPendingArray removeObject: s];
            }
        }
    }
}

- (void)clearAllMessages {
    [self.positions_array removeAllObjects];

}


@end
