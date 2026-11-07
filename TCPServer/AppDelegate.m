//
//  AppDelegate.m
//  TCPServer
//
//  Created by Benjamin Völker on 06/08/15.
//  Copyright © 2015 Benjamin Völker. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [self.appController showMainWindow];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  [self.appController stopAllServers];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
  return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
  if (!flag) [self.appController showMainWindow];
  return YES;
}

- (void) awakeFromNib {
  self.appController = [[AppController alloc] init];
}

- (void) launchWindow:(id)sender{
  [self.appController makeNewWindow:self];
}

@end
