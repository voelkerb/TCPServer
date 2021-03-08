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

@interface WindowController : NSWindowController<GCDAsyncSocketDelegate> {
  dispatch_queue_t socketQueue;
  
  GCDAsyncSocket *listenSocket;
  NSMutableArray *connectedSockets;
}

@property (weak) IBOutlet NSButton *startStopButton;
@property (weak) IBOutlet NSTextField *portTextField;
@property (weak) IBOutlet NSTextField *sendMsgTextField;
@property (unsafe_unretained) IBOutlet NSTextView *receiveMsgTextView;
@property (weak) IBOutlet NSButton *autoScroll;

- (IBAction)startStop:(id)sender;
- (IBAction)sendData:(id)sender;
- (IBAction)clearAction:(id)sender;

@end
