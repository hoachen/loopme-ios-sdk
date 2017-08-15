//
//  LoopMeBrowserViewController
//  LoopMeSDK
//
//  Created by Dmitriy Lihachov on 8/21/12.
//  Copyright (c) 2012 LoopMe. All rights reserved.
//

@class LoopMeBrowserViewController;

@protocol LoopMeBrowserControllerDelegate;

@interface LoopMeBrowserViewController : UIViewController <UIWebViewDelegate, UIActionSheetDelegate>

@property (nonatomic, weak) id<LoopMeBrowserControllerDelegate> delegate;
@property (nonatomic, copy) NSURL *URL;

- (instancetype)initWithURL:(NSURL *)URL
       HTMLString:(NSString *)HTMLString
         delegate:(id<LoopMeBrowserControllerDelegate>)delegate;
- (void)layoutBrowseToolbar;

@end

@protocol LoopMeBrowserControllerDelegate

- (void)dismissBrowserController:(LoopMeBrowserViewController *)browserController
                        animated:(BOOL)animated;

@end