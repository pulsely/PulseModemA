//
//  APRSPositionManager.h
//  PulseModemA
//
//  Created by Pulsely on 7/29/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "APRSTCPManager.h"
#import <UIKit/UIKit.h>

@interface APRSPositionManager : NSObject  <GCDAsyncSocketDelegate, APRSTCPManagerDelegate>

@property (nonatomic, retain) GCDAsyncSocket *telnetSocket;
@property (strong, nonatomic) APRSTCPManager *tcp_manager;

@property (nonatomic, assign) BOOL connected;
@property (nonatomic, assign) BOOL flag_login_sent;

@property (nonatomic, retain) NSMutableArray *positions_array;
@property (nonatomic, retain) NSMutableArray *callsigns_mapkit_array;
@property (nonatomic, retain) NSMutableDictionary *callsigns_dict;
@property (strong, nonatomic) NSMutableArray *messagesPendingArray;

+ (id)sharedManager;


- (NSMutableArray *)positions_latest;

- (void)setup;

- (void)connectAction:(id)sender;
- (void)reconnectSocketAction:(id)sender;
- (void)disconnectNotificationAction:(NSNotification *)notification;

- (void)addAPRSPosition:(NSDictionary *)payload source:(NSString *)source_name;

- (void)writeMessages;

@end
