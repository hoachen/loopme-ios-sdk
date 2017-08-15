 //
//  LoopMeBrowserController.m
//  LoopMeSDK
//
//  Created by Dmitriy Lihachov on 8/21/12.
//  Copyright (c) 2012 LoopMe. All rights reserved.
//

#import <MessageUI/MessageUI.h>

#import "LoopMeBrowserViewController.h"
#import "LoopMeDefinitions.h"
#import "LoopMeDestinationDisplayController.h"
#import "LoopMeBackView.h"
#import "LoopMeURLResolver.h"
#import "NSURL+LoopMeAdditions.h"
#import "UIImage+LoopMeBinaryImage.h"
#import "LoopMeLogging.h"

@interface LoopMeBrowserViewController ()
<
    MFMailComposeViewControllerDelegate
>
@property (nonatomic, strong) UIActionSheet *actionSheet;
@property (nonatomic, strong) NSString *HTMLString;
@property (nonatomic, assign) int webViewLoadCount;
@property (nonatomic, strong) UIWebView *webView;

@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIBarButtonItem *backButton;
@property (nonatomic, strong) UIBarButtonItem *refreshButton;
@property (nonatomic, strong) UIBarButtonItem *safariButton;
@property (nonatomic, strong) UIBarButtonItem *doneButton;
@property (nonatomic, assign, getter = isBrowserWasClicked) BOOL browserWasClicked;

- (void)cleanUp;
- (void)refreshBackButtonState;
- (void)refresh;
- (void)done;
- (void)back:(id)sender;
- (void)safari;
- (void)dismissActionSheetAnimated:(BOOL)animated;
- (BOOL)canHandleURL:(NSURL *)URL;
- (void)handleURL:(NSURL *)URL;

@end

@implementation LoopMeBrowserViewController

#pragma mark - Properties

- (UIWebView *)webView {
    if (!_webView) {
        _webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 44)];
        _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;
        _webView.delegate = self;
        _webView.scalesPageToFit = YES;
        [self.view addSubview:_webView];
        self.webViewLoadCount = 0;
    }
    return _webView;
}

#pragma mark - Lifecycle

- (instancetype)initWithURL:(NSURL *)URL
       HTMLString:(NSString *)HTMLString
         delegate:(id<LoopMeBrowserControllerDelegate>)delegate {
    if (self = [super init]) {
        [self view];
        _delegate = delegate;
        _URL = URL;
        _HTMLString = HTMLString;
        self.view.backgroundColor = [UIColor blackColor];
        [self webView];
        
        [_webView loadRequest:[NSURLRequest requestWithURL:URL]];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshBackButtonState];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self dismissActionSheetAnimated:NO];
}

#pragma mark - Private

- (void)cleanUp {
    [self.webView stringByEvaluatingJavaScriptFromString:@"document.body.innerHTML = \"\";"];
    [self.webView removeFromSuperview];
    self.webView.delegate = nil;
    [self.webView stopLoading];
}

- (void)refreshBackButtonState {
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        LoopMeBackView *backView = (LoopMeBackView *)self.backButton.customView;
        backView.active = self.webView.canGoBack;
        
        if (self.isBrowserWasClicked) {
            backView.active = YES;
        }
    } else {
        UIButton *backButton = (UIButton *)self.backButton;
        backButton.enabled = self.webView.canGoBack;
        
        if (self.isBrowserWasClicked) {
            backButton.enabled = YES;
        }
    }
}

#pragma mark Hidding status bar (iOS 7 and above)

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark Navigation

- (void)refresh {
    [self dismissActionSheetAnimated:YES];
    
    if (!self.webView.request.URL.absoluteString || [self.webView.request.URL.absoluteString isEqualToString:@"about:blank"]) {
        [self.webView loadHTMLString:self.HTMLString baseURL:nil];
    } else {
        [self.webView reload];
    }
}

- (void)done {
    [self dismissActionSheetAnimated:YES];

    [self cleanUp];
    if (self.delegate) {
        [self.delegate dismissBrowserController:self
                                       animated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)back:(id)sender {
    if (SYSTEM_VERSION_LESS_THAN(@"7.0")) {
        UIButton *b = (UIButton *)sender;
        b.highlighted = NO;
    }

    [self dismissActionSheetAnimated:YES];
 
    if ([self.webView canGoBack]) {
        [self.webView goBack];
    } else if (!self.webView.canGoBack && self.isBrowserWasClicked) {
        [self.webView removeFromSuperview];
        self.webView.delegate = self;
        self.webView = nil;
        
        [self.webView loadHTMLString:self.HTMLString baseURL:nil];
        self.browserWasClicked = NO;
    }
}

- (void)safari {
    if (self.actionSheet) {
        [self dismissActionSheetAnimated:YES];
    } else {
        self.actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Open in Safari", @"Share via Email", nil];

        if ([self.actionSheet respondsToSelector:@selector(showFromBarButtonItem:animated:)]) {
            [self.actionSheet showFromBarButtonItem:self.safariButton animated:YES];
        } else {
            [self.actionSheet showInView:self.webView];
        }
    }
}

- (void)dismissActionSheetAnimated:(BOOL)animated {
    [self.actionSheet dismissWithClickedButtonIndex:0 animated:animated];
}

- (BOOL)canHandleURL:(NSURL *)URL {
    if ([LoopMeURLResolver storeItemIdentifierForURL:URL]) {
        return YES;
    } else if ([LoopMeURLResolver mailToForURL:URL]) {
        return YES;
    } else if ([LoopMeURLResolver telLinkForURL:URL]) {
        return YES;
    }
    
    return NO;
}

- (void)handleURL:(NSURL *)URL {
    if  ([LoopMeURLResolver storeItemIdentifierForURL:URL]) {
        LoopMeDestinationDisplayController *displayController = (LoopMeDestinationDisplayController *)self.delegate;
        [displayController showStoreKitProductWithParameter:[LoopMeURLResolver storeItemIdentifierForURL:URL] fallbackURL:URL];
    } else {
        if ([[UIApplication sharedApplication] canOpenURL:self.URL]) {
            [[UIApplication sharedApplication] openURL:self.URL];
        }
    }
}
#pragma mark Orientation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - Public

- (void)layoutBrowseToolbar {
    self.spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectZero];
    [self.spinner sizeToFit];
    self.spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    self.spinner.hidesWhenStopped = YES;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        LoopMeBackView *backView = [[LoopMeBackView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
        self.backButton = [[UIBarButtonItem alloc] initWithCustomView:backView];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(back:)];
        [backView addGestureRecognizer:tap];
    } else {
        UIButton *back = [UIButton buttonWithType:UIButtonTypeCustom];
        back.frame = CGRectMake(0, 0, 44, 44);
        [back setImage:[UIImage imageFromDataOfType:LoopMeImageTypeBrowserBackActive] forState:UIControlStateNormal];
        [back setImage:[UIImage imageFromDataOfType:LoopMeImageTypeBrowserBack] forState:UIControlStateDisabled];
        [back setImage:[UIImage imageFromDataOfType:LoopMeImageTypeBrowserBack] forState:UIControlStateHighlighted];
        [back addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
        self.backButton = [[UIBarButtonItem alloc] initWithCustomView:back];
    }
    
    self.doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                    target:self
                                                                    action:@selector(done)];
    
    
    self.refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                       target:self
                                                                       action:@selector(refresh)];
    
    self.safariButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                      target:self
                                                                      action:@selector(safari)];
    
    
    UIBarButtonItem *flexiSpace1 = [[UIBarButtonItem alloc]
                                    initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                    target:nil
                                    action:nil];
    
    
    UIBarButtonItem *spinnerItem = [[UIBarButtonItem alloc] initWithTitle:@"S"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:nil
                                                                   action:nil];
    spinnerItem.customView = self.spinner;
    
    UIToolbar *browseToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 44, self.view.bounds.size.width, 44)];
    
    browseToolbar.barStyle = UIBarStyleBlackTranslucent;
    
    browseToolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    browseToolbar.items = @[self.backButton, flexiSpace1, self.refreshButton, flexiSpace1, self.safariButton, flexiSpace1, spinnerItem, flexiSpace1, self.doneButton];
    
    [self.view addSubview:browseToolbar];
}


#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    self.actionSheet = nil;
    if (buttonIndex == 0) {
        LoopMeDestinationDisplayController *displayController = (LoopMeDestinationDisplayController *)self.delegate;
        [displayController openURLInApplication:self.URL];
    }
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType {
    LoopMeLogDebug(@"Ad browser loads URL: %@", request.URL.absoluteString);
    
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        self.browserWasClicked = YES;
    }
    
    if (navigationType != UIWebViewNavigationTypeOther) {
        self.URL = request.URL;
    }
    
    if ([self canHandleURL:request.URL]) {
        [self handleURL:request.URL];
        return NO;
    }
    
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    self.refreshButton.enabled = YES;
    self.safariButton.enabled = YES;
 
    [self.spinner startAnimating];

    self.webViewLoadCount++;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.webViewLoadCount--;
    [self refreshBackButtonState];

    if (self.webViewLoadCount > 0) return;

    self.refreshButton.enabled = YES;
    self.safariButton.enabled = YES;
    
    [self.spinner stopAnimating];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    self.webViewLoadCount--;

    self.refreshButton.enabled = YES;
    self.safariButton.enabled = YES;

    [self refreshBackButtonState];
    
    [self.spinner stopAnimating];

    // Ignore NSURLErrorDomain error (-999).
    if (error.code == NSURLErrorCancelled) return;

    // Ignore "Frame Load Interrupted" errors after navigating to iTunes or the App Store.
    if (error.code == 102 && [error.domain isEqual:@"WebKitErrorDomain"]) return;
    
    LoopMeLogDebug(@"Ad browser got an error: %@", error);
}

#pragma mark - MailComposerDelegates

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
