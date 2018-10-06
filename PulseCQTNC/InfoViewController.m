//
//  ViewController.m
//  PulseSat
//
//  Created by Pulsely on 12/5/16.
//  Copyright © 2016 Pulsely Consulting. All rights reserved.
//

#import "InfoViewController.h"
#import <NSLogger/NSLogger.h>

@interface InfoViewController ()

@end

@implementation InfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Getting started? ⚠️"; //[self.d objectForKey: @"title"];
    
    [self showIntroWithCustomPages];
}

- (void)showIntroWithCustomPages {
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"www/1_getting_started/index" ofType:@"html"];
    
    NSFileHandle *readHandle = [NSFileHandle fileHandleForReadingAtPath: filepath];
    
    NSString *htmlString = [[NSString alloc] initWithData:
                            [readHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
    
    NSString *basepath = [[NSBundle mainBundle] bundlePath];
    basepath = [NSString stringWithFormat: @"%@/www/1_getting_started", basepath];
    
    NSURL *baseURL = [NSURL fileURLWithPath:basepath];
    
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    //self.webView.delegate = self;
    [self.webView sizeToFit];
    
    self.webView.opaque = NO;
    self.webView.backgroundColor = [UIColor clearColor];
    
    [self.webView loadHTMLString: htmlString baseURL: baseURL];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
