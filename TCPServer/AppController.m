//
//  AppController.m
//  TCPConnectionTest
//
//  Created by Benjamin Völker on 05/08/15.
//  Copyright © 2015 Benjamin Völker. All rights reserved.
//

#import "AppController.h"

@implementation AppController

- (void)showMainWindow {
    if (!self.mainWindowController) {
        self.mainWindowController = [[MainWindowController alloc] init];
    }
    [self.mainWindowController showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)makeNewWindow:(id)sender {
    [self showMainWindow];
    [self.mainWindowController addServer];
}

- (void)stopAllServers {
    [self.mainWindowController stopAllServers];
}

@end
