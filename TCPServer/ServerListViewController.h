//
//  ServerListViewController.h
//  TCPServer
//

#import <Cocoa/Cocoa.h>
#import "ServerSession.h"

NS_ASSUME_NONNULL_BEGIN

@class ServerListViewController;

@protocol ServerListViewControllerDelegate <NSObject>
- (void)serverList:(ServerListViewController *)list didSelectSession:(nullable ServerSession *)session;
@end

@interface ServerListViewController : NSViewController

@property (nonatomic, weak, nullable) id<ServerListViewControllerDelegate> delegate;
@property (nonatomic, readonly, nullable) ServerSession *selectedSession;
@property (nonatomic, readonly) NSArray<ServerSession *> *sessions;

- (void)addServer;
- (void)removeSelectedServer;
- (void)stopAllServers;

@end

NS_ASSUME_NONNULL_END
