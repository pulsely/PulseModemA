//
//  ViewController.h
//  MultimonIOS
//
//  Created by Pulsely on 6/21/18.
//  Copyright © 2018 Pulsely. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HomescreenViewController : UIViewController {
    
}
@property (nonatomic, retain) IBOutlet UITextView *textview;
@property (nonatomic, retain) NSMutableAttributedString *string_buffer;

//- (void)addMessage: (NSString *) toTextView:(UITextView *)textview;
- (BOOL)isHeadsetPluggedIn;

@end

