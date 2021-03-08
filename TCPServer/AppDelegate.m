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
  // Insert code here to initialize your application
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  // Insert code here to tear down your application
}

- (void) awakeFromNib {
  self.appController = [[AppController alloc] init];
}


- (void) launchWindow:(id)sender{
  NSLog(@"Launch window");
  [self.appController makeNewWindow:self];
}

@end
