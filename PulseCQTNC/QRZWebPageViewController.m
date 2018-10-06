//
//  QRZWebPageViewController.m
//  PulseModemA
//
//  Created by Pulsely on 8/4/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import "QRZWebPageViewController.h"

@interface QRZWebPageViewController () {
    
}

@end

@implementation QRZWebPageViewController
@synthesize callsign;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.webview.delegate = self;
    self.webview.progressDelegate = self;

    [self loadQRZ];
    
    self.title = @"QRZ page";
}

-(void)loadQRZ
{
    NSString *url = [NSString stringWithFormat: @"https://qrz.com/db/%@/", self.callsign];
    NSURLRequest *req = [[NSURLRequest alloc] initWithURL: [NSURL URLWithString: url]];
    [self.webview loadRequest: req];
}



#pragma mark - NJKWebViewProgressDelegate

-(void)webViewProgress:(NJKWebViewProgress *)webViewProgress updateProgress:(float)progress {
    [self.progressview setProgress: progress];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
