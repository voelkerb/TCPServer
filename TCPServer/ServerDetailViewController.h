//
//  ServerDetailViewController.h
//  TCPServer
//

#import <Cocoa/Cocoa.h>
#import "ServerSession.h"

NS_ASSUME_NONNULL_BEGIN

@interface ServerDetailViewController : NSViewController

// Pass nil to show the empty state.
@property (nonatomic, strong, nullable) ServerSession *session;
// Used to detect port clashes with other running servers.
@property (nonatomic, copy, nullable) NSArray<ServerSession *> *(^allSessionsProvider)(void);

@end

NS_ASSUME_NONNULL_END
