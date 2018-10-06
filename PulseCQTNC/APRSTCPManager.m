//
//  DXClustersTelnetManager.m
//  PulseCQ
//
//  Created by Pulsely on 11/11/16.
//  Copyright © 2016 Pulsely. All rights reserved.
//

#import "APRSTCPManager.h"
#import <Foundation/Foundation.h>
#import <NSLogger/NSLogger.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import "INTULocationManager.h"
#import <RMessage.h>

@implementation APRSTCPManager

-(id)init
{
    self = [super init];
    if (self)
    {
        self.bytesRead = @(0);

    }
    return self;
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    LoggerApp(1, @"APRSTCPManager> didConnectToHost - %@", host);
    self.inSocket = sock;
    
    [sock readDataWithTimeout: 10 tag:0];   // switch to 10 for better timeout management
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
//    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Disconnected" message:@"Unfortunately server disconnected" delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:nil, nil];
//    [alert show];
    
//    if (self.inSocket) {
//        [self.inSocket connectToHost:@"arda.pp.ru" onPort:7000 error:nil];
//    }
    LoggerApp(1, @"APRSTCPManager> socketDidDisconnect");
    [[NSNotificationCenter defaultCenter] postNotificationName: NOTIFICATION_APRSTCP_SOCKET_DISCONNECTED object: err];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    
    //NSString *socket_data = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //LoggerApp(1, @"APRSTCPManager> didReadData: %@", socket_data);
    
    if (self.delegate) {
        [self.delegate telnetManager:self didReceiveData:data];
    }
    
    [sock readDataWithTimeout:-1 tag:tag];
}

-(void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    [sock readDataWithTimeout: -1 tag:tag];
}

- (IBAction)sendLogin:(id)sender {
    UICKeyChainStore *keychain = [UICKeyChainStore keyChainStoreWithService: KEY_CHAIN_SERVICE_DOMAIN];
    NSString *callsign = keychain[KEYCHAIN_CALLSIGN];
    NSString *passcode = keychain[KEYCHAIN_PASSCODE];
    
    if ( (callsign != nil) && (passcode != nil)) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        double last_latitude = [defaults doubleForKey: NSUSERDEFAULTS_LAST_LATITUDE];
        double last_longitude = [defaults doubleForKey: NSUSERDEFAULTS_LAST_LONGITUDE];
        
        // overwrite for demo purposes
//        last_latitude = 37.331122;
//        last_longitude = -122.030214;
        
        NSString *loginmessage = [NSString stringWithFormat: @"user %@ pass %@ vers %@ filter r/%.2f/%.2f/100\r\n", callsign, passcode, APRS_USER_AGENT_STRING, last_latitude, last_longitude];
        
        LoggerApp(1, @"APRSTCPManager> sendLogin: %@", loginmessage);
        
        //[loginmessage_bytes appendData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];
        
        [self.inSocket writeData: [[loginmessage dataUsingEncoding:NSUTF8StringEncoding] mutableCopy] withTimeout: 10.0 tag:1];
    } else {
        [RMessage showNotificationWithTitle: @"No credentials"
                                   subtitle: @"Enter your callsign and password"
                                       type: RMessageTypeError
                             customTypeName:nil
                                   callback:nil];
    }
    

}




- (void)socketWriteString:(NSString *)str {
    NSString *aprs_message = [NSString stringWithFormat: @"%@\r\n", str];
    
    [self.inSocket writeData: [[aprs_message dataUsingEncoding:NSUTF8StringEncoding] mutableCopy] withTimeout: 10.0 tag:1];
}


- (void)disconnect {
    [self.inSocket disconnect];
}


@end
