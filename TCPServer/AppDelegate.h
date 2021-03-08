//
//  AppDelegate.h
//  TCPServer
//
//  Created by Benjamin Völker on 06/08/15.
//  Copyright © 2015 Benjamin Völker. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AppController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (retain) AppController *appController;

-(IBAction)launchWindow:(id)sender;


@end

