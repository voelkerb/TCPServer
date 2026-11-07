//
//  ServerSession.h
//  TCPServer
//
//  One TCP listener with its clients and activity log.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// Posted on the main thread when name, port, running state or client count changes.
extern NSNotificationName const ServerSessionDidChangeNotification;
// Posted on the main thread after a line is appended to or cleared from the log.
extern NSNotificationName const ServerSessionDidUpdateLogNotification;

typedef NS_ENUM(NSInteger, ServerLogKind) {
    ServerLogKindInfo,
    ServerLogKindReceived,
    ServerLogKindSent,
    ServerLogKindError,
};

@interface ServerSession : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic) uint16_t port;
@property (nonatomic, readonly) BOOL running;
@property (nonatomic, readonly) NSUInteger clientCount;
// Main-thread only. Safe to attach to a layout manager.
@property (nonatomic, readonly) NSTextStorage *log;

- (instancetype)initWithName:(NSString *)name port:(uint16_t)port NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;

- (BOOL)startWithError:(NSError **)error;
- (void)stop;
// Returns the number of clients the line was sent to.
- (NSUInteger)sendLine:(NSString *)line;
- (void)clearLog;

@end

NS_ASSUME_NONNULL_END
