//
//  DXClustersTelnetManager
//  PulseCQ
//
//  Created by Pulsely on 11/11/16.
//  Copyright © 2016 Pulsely. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

@class APRSTCPManager;

@protocol APRSTCPManagerDelegate <NSObject>

@optional
- (void) telnetManager:(APRSTCPManager *)manager didReceiveData:(NSData *)data;

@end


@interface APRSTCPManager : NSObject <GCDAsyncSocketDelegate>

@property (nonatomic) NSMutableData *data;
@property (nonatomic) NSNumber *bytesRead;
@property (nonatomic) id<APRSTCPManagerDelegate> delegate;
@property (strong, nonatomic) GCDAsyncSocket *inSocket;


- (IBAction)sendLogin:(id)sender;
- (void)disconnect;

- (void)writeAPRSPosition:(NSString*)aprs_message;
- (void)socketWriteString:(NSString *)str;

@end
