//
//  AppController.m
//  TCPServer
//
//  Created by Benjamin Völker on 06/08/15.
//  Copyright © 2015 Benjamin Völker. All rights reserved.
//

#import "WindowController.h"

#define WELCOME_MSG  0
#define ECHO_MSG     1
#define WARNING_MSG  2

// No timeout here
#define READ_TIMEOUT -1
#define READ_TIMEOUT_EXTENSION -1

@implementation WindowController
@synthesize sendMsgTextField, receiveMsgTextView, portTextField, startStopButton, autoScroll;

bool serverStarted;

- (void)windowDidLoad {
    [super windowDidLoad];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}
/*
 * Init funciton
 */
- (id)init {
  if((self = [super init])) {
    serverStarted = false;
		socketQueue = dispatch_queue_create("socketQueue", NULL);
		listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
		
		// Setup an array to store all accepted client connections
    connectedSockets = [[NSMutableArray alloc] init];
    
    // Set the string value of the textfields
    [receiveMsgTextView setString:@""];
  }
  return self;
}

- (IBAction)clearAction:(id)sender {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSAttributedString* attr = [[NSAttributedString alloc] initWithString:@""];
      
    [[self.receiveMsgTextView textStorage] setAttributedString:attr];
  });
}

/*
 * Append a message to the textview
 */
- (void)appendMsg:(NSString *)msg {
//  NSString *paragraph = [NSString stringWithFormat:@"%@\n", msg];
//  NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1];
////  [attributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
//  NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
//  [[receiveMsgTextView textStorage] appendAttributedString:as];
  NSAttributedString* attr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", msg]];
  [[self.receiveMsgTextView textStorage] appendAttributedString:attr];
  [self.receiveMsgTextView setTextColor:NSColor.textColor];
  // Scroll to bottom

    if ( [self.autoScroll state] == NSOnState ) {
        [self scrollToBottom];
    }
}

/*
 * Scroll the text view to the bottom
 */
- (void)scrollToBottom {
  // Get the scrollview of the textview
  NSScrollView *scrollView = [receiveMsgTextView enclosingScrollView];
  NSPoint newScrollOrigin;
  if ([[scrollView documentView] isFlipped]) newScrollOrigin = NSMakePoint(0.0F, NSMaxY([[scrollView documentView] frame]));
  else newScrollOrigin = NSMakePoint(0.0F, 0.0F);
  [[scrollView documentView] scrollPoint:newScrollOrigin];
}

/*
 * Send data to all the socket clients, called on send or enter pressed
 */
- (IBAction)sendData:(id)sender {
  // Get the message append a newline and clear the message textfiel
  NSString *msg = [NSString stringWithFormat:@"%@\n", [sendMsgTextField stringValue]];
  [sendMsgTextField setStringValue:@""];
  // Decode string into data and send it to all available socket connections
  NSData *data = [msg dataUsingEncoding:NSUTF8StringEncoding];
  for (int i = 0; i < [connectedSockets count]; i++){
    @synchronized(connectedSockets){
      [[connectedSockets objectAtIndex:i] writeData:data withTimeout:-1 tag:0];
    }
  }
}

/*
 * Start or stop the tcp server
 */
- (IBAction)startStop:(id)sender {
  
  if (sender != startStopButton && serverStarted)  {
    return;
  }
  // If server is currently not running
  if([[startStopButton title] isEqualToString:@"Start"]) {
    // Get desired port
    int port = [portTextField intValue];
    // if port is beyond bounds return
    if (port < 0 || port > 65535) {
      [portTextField setStringValue:@""];
      port = 0;
      return;
    }
    // Try to open port
    NSError *error = nil;
    if(![listenSocket acceptOnPort:port error:&error]) {
      // If open fails
      NSLog(@"Error starting server: %@", error);
      return;
    }
    serverStarted = true;
    // If open succeeded
    NSLog(@"Echo server started on local port %hu", [listenSocket localPort]);
    // The portTextfield is not allowed to change now
    [portTextField setEnabled:NO];
    // Set button to stop
    [startStopButton setTitle:@"Stop"];
  // If server is currently running
  } else {
    // Stop accepting connections
    [listenSocket disconnect];
    // Stop any client connections
    NSUInteger i;
    for (i = 0; i < [connectedSockets count]; i++) {
      @synchronized(connectedSockets){
        [[connectedSockets objectAtIndex:i] disconnect];
      }
    }
    serverStarted = false;
    NSLog(@"Stopped server");
    // Set the port textfield back to editable and the button to start
    [portTextField setEnabled:YES];
    [startStopButton setTitle:@"Start"];
  }
}

#pragma mark Socket delegate functions
/*
 * If a new client is connected to the server.
 */
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
  // This method is executed on the socketQueue (not the main thread)
  @synchronized(connectedSockets) {
    [connectedSockets addObject:newSocket];
  }
  
  // Get ip and port
  NSString *host = [newSocket connectedHost];
  UInt16 port = [newSocket connectedPort];
  dispatch_async(dispatch_get_main_queue(), ^{
    @autoreleasepool {
      [self appendMsg:[NSString stringWithFormat:@"Accepted client %@:%hu", host, port]];
    }
  });
  // Let the socket be able to write data to us
  [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:0];
}

/*
 * If the socket did write data successfully, allow that data could be read again
 */
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
  // This method is executed on the socketQueue (not the main thread)
  [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:0];
}

/*
 * Is called if data from a socket is read
 */
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
  // This method is executed on the socketQueue (not the main thread)
  dispatch_async(dispatch_get_main_queue(), ^{
    @autoreleasepool {
      NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
      NSString *msg = [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];
      if (msg) [self appendMsg:msg];
      else [self appendMsg:@"Error converting received data into UTF-8 String"];
    }
  });
  // Allow new data comming in
  [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:0];
}

/**
 * This method is called if a read has timed out.
 * It allows us to optionally extend the timeout.
 * We use this method to issue a warning to the user prior to disconnecting them.
 **//*
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
  if (elapsed <= READ_TIMEOUT) {
    NSString *warningMsg = @"Are you still there?\r\n";
    NSData *warningData = [warningMsg dataUsingEncoding:NSUTF8StringEncoding];
    
    [sock writeData:warningData withTimeout:-1 tag:WARNING_MSG];
    
    return READ_TIMEOUT_EXTENSION;
  }
  
  return 0.0;
}*/

/*
 * If a socket disconnected, remove it from the list of sockets
 */
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
  // If the socket is not equal to the listening sockets
  if (sock != listenSocket) {
    dispatch_async(dispatch_get_main_queue(), ^{
      @autoreleasepool {
        [self appendMsg:@"Client Disconnected"];
      }
    });
    // Remove from the list of sockets
    @synchronized(connectedSockets) {
      [connectedSockets removeObject:sock];
    }
  }
}



@end
