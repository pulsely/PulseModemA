#import "UIWebView+Progress.h"
#import "ISMethodSwizzling.h"
#import <objc/runtime.h>

static const char NJKProgressProxyKey;

@interface UIWebView () <UIWebViewDelegate>

@property (nonatomic, strong) NJKWebViewProgress *progressProxy;
@property (nonatomic, njk_weak) id <UIWebViewDelegate> webViewProxyDelegate;

@end

@implementation UIWebView (Progress)

+ (void)load
{
    @autoreleasepool {
        ISSwizzleInstanceMethod([self class], @selector(initWithFrame:), @selector(_initWithFrame:));
        ISSwizzleInstanceMethod([self class], @selector(initWithCoder:), @selector(_initWithCoder:));
        ISSwizzleInstanceMethod([self class], @selector(delegate),       @selector(_delegate));
        ISSwizzleInstanceMethod([self class], @selector(setDelegate:),   @selector(_setDelegate:));
    }
}

- (id)_initWithFrame:(CGRect)frame
{
    self = [self _initWithFrame:frame];
    if (self) {
        self.progressProxy = [[NJKWebViewProgress alloc] init];
        self.delegate = self.progressProxy;
    }
    return self;
}

- (id)_initWithCoder:(NSCoder *)coder
{
    self = [self _initWithCoder:coder];
    if (self) {
        self.progressProxy = [[NJKWebViewProgress alloc] init];
        self.delegate = self.progressProxy;
    }
    return self;
}

#pragma mark - accessors

- (NJKWebViewProgress *)progressProxy
{
    return objc_getAssociatedObject(self, &NJKProgressProxyKey);
}

- (void)setProgressProxy:(NJKWebViewProgress *)progressProxy
{
    objc_setAssociatedObject(self, &NJKProgressProxyKey, progressProxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id <NJKWebViewProgressDelegate>)progressDelegate
{
    return self.progressProxy.progressDelegate;
}

- (void)setProgressDelegate:(id<NJKWebViewProgressDelegate>)progressDelegate
{
    self.progressProxy.progressDelegate = progressDelegate;
}

- (float)progress
{
    return self.progressProxy.progress;
}

- (id <UIWebViewDelegate>)_delegate
{
    return self.progressProxy.webViewProxyDelegate;
}

- (void)_setDelegate:(id<UIWebViewDelegate>)delegate
{
    if ([self _delegate] && delegate != self.progressProxy) {
        self.progressProxy.webViewProxyDelegate = delegate;
        return;
    }
    [self _setDelegate:delegate];
}

@end
