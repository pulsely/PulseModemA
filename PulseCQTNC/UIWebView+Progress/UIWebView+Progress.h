#import <UIKit/UIKit.h>
#import "NJKWebViewProgress.h"

@interface UIWebView (Progress)

@property (nonatomic, njk_weak) id <NJKWebViewProgressDelegate> progressDelegate;
@property (nonatomic, readonly) float progress; // 0.0..1.0

@end
