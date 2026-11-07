//
//  AppController.h
//  TCPServer
//
//  Created by Benjamin Völker on 06/08/15.
//  Copyright © 2015 Benjamin Völker. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "MainWindowController.h"

@interface AppController : NSObject

@property(nonatomic, strong) MainWindowController *mainWindowController;

// Shows the main window, creating it on first use.
- (void)showMainWindow;
// Adds a new server to the main window and shows it.
- (IBAction)makeNewWindow:(id)sender;
- (void)stopAllServers;

@end
