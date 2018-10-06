//
//  LibfapHelper.h
//  MultimonIOS
//
//  Created by Pulsely on 6/27/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LibfapHelper : NSObject

- (NSDictionary *)aprsparsed:(NSString *)aprs_message;

@end
