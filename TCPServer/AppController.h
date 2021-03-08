//
//  AppController.h
//  TCPServer
//
//  Created by Benjamin Völker on 06/08/15.
//  Copyright © 2015 Benjamin Völker. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "GCDAsyncSocket.h"
#import "WindowController.h"

@interface AppController : NSObject {
}

@property(nonatomic, strong) NSMutableArray *sessionWindowControllers;
@property(nonatomic, strong) WindowController *currentWindowController;

- (IBAction)makeNewWindow:(id)sender;

@end
