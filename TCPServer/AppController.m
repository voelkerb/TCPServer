//
//  AppController.m
//  TCPConnectionTest
//
//  Created by Benjamin Völker on 05/08/15.
//  Copyright © 2015 Benjamin Völker. All rights reserved.
//

#import "AppController.h"


@implementation AppController

@synthesize sessionWindowControllers, currentWindowController;

- (id)init {
  if (self = [super init]) {
    self.sessionWindowControllers = [[NSMutableArray alloc] initWithCapacity:1];
    self.currentWindowController = [[WindowController alloc] initWithWindowNibName:@"myWindow"];
    [self.sessionWindowControllers addObject:currentWindowController];
    [self.currentWindowController showWindow:self];
  }
  return self;
}


- (void)makeNewWindow:(id)sender {
  self.currentWindowController = [[WindowController alloc] initWithWindowNibName:@"myWindow"];
  [self.sessionWindowControllers addObject:currentWindowController];
  [self.currentWindowController showWindow:self];
}

@end
