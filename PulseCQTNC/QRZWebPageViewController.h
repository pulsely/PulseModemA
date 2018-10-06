//
//  QRZWebPageViewController.h
//  PulseModemA
//
//  Created by Pulsely on 8/4/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "UIWebView+Progress.h"

@interface QRZWebPageViewController : UIViewController <UIWebViewDelegate> {
    
}
@property (nonatomic, retain) IBOutlet UIWebView *webview;
@property (nonatomic, retain) IBOutlet UIProgressView *progressview;

@property (nonatomic, retain) NSString *callsign;

@end
