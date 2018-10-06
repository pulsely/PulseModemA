//
//  APRSDecodeManager.h
//  PulseModemA
//
//  Created by Pulsely on 4/10/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MultimonHelper.h"


@interface APRSTextStreamDecodeManager : NSObject {
    
}
//@property (nonatomic, retain) CAFSK12Decoder *decoder;

@property (nonatomic, retain) NSString *string_buffer;
@property (nonatomic, retain) NSString *current_message;

@property (nonatomic, retain) NSPipe *pipe;
@property (nonatomic, retain) NSFileHandle *pipeHandle;
@property (nonatomic, retain) dispatch_source_t source;
@property (nonatomic, retain) MultimonHelper *h;

+ (id)sharedManager;

- (void)decodeRFAPRS;

@end
