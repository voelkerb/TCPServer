//
//  ServerSession.m
//  TCPServer
//

#import "ServerSession.h"
#import "GCDAsyncSocket.h"

NSNotificationName const ServerSessionDidChangeNotification = @"ServerSessionDidChangeNotification";
NSNotificationName const ServerSessionDidUpdateLogNotification = @"ServerSessionDidUpdateLogNotification";

static const NSUInteger kMaxLogLength = 500000;

@interface ServerSession () <GCDAsyncSocketDelegate> {
    dispatch_queue_t _queue;
    GCDAsyncSocket *_listenSocket;
    NSMutableArray<GCDAsyncSocket *> *_clients;
    NSDateFormatter *_timeFormatter;
    NSData *_lineDelimiter;
}
@property (nonatomic, readwrite) BOOL running;
@end

@implementation ServerSession

- (instancetype)initWithName:(NSString *)name port:(uint16_t)port {
    self = [super init];
    if (self) {
        _name = [name copy];
        _port = port;
        _queue = dispatch_queue_create("com.voelkerb.TCPServer.session", DISPATCH_QUEUE_SERIAL);
        _clients = [[NSMutableArray alloc] init];
        _log = [[NSTextStorage alloc] init];
        _lineDelimiter = [NSData dataWithBytes:"\n" length:1];
        _timeFormatter = [[NSDateFormatter alloc] init];
        _timeFormatter.dateFormat = @"HH:mm:ss";
    }
    return self;
}

- (nullable instancetype)initWithDictionary:(NSDictionary *)dictionary {
    NSString *name = dictionary[@"name"];
    NSNumber *port = dictionary[@"port"];
    if (![name isKindOfClass:NSString.class] || ![port isKindOfClass:NSNumber.class]) {
        return nil;
    }
    return [self initWithName:name port:(uint16_t)port.unsignedIntegerValue];
}

- (NSDictionary *)dictionaryRepresentation {
    return @{ @"name": self.name, @"port": @(self.port) };
}

- (NSUInteger)clientCount {
    @synchronized (_clients) {
        return _clients.count;
    }
}

- (void)setName:(NSString *)name {
    _name = [name copy];
    [self postChange];
}

- (void)setPort:(uint16_t)port {
    if (_port == port) return;
    _port = port;
    [self postChange];
}

#pragma mark - Lifecycle

- (BOOL)startWithError:(NSError **)error {
    if (self.running) return YES;

    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_queue];
    if (![socket acceptOnPort:self.port error:error]) {
        [self appendLine:[NSString stringWithFormat:@"Could not listen on port %hu: %@",
                          self.port, (error && *error) ? (*error).localizedDescription : @"unknown error"]
                    kind:ServerLogKindError];
        return NO;
    }
    _listenSocket = socket;
    self.running = YES;
    [self appendLine:[NSString stringWithFormat:@"Listening on port %hu", self.port] kind:ServerLogKindInfo];
    [self postChange];
    return YES;
}

- (void)stop {
    if (!self.running) return;

    GCDAsyncSocket *listener = _listenSocket;
    _listenSocket = nil;
    self.running = NO;
    [listener setDelegate:nil delegateQueue:NULL];
    [listener disconnect];

    NSArray<GCDAsyncSocket *> *clients;
    @synchronized (_clients) {
        clients = [_clients copy];
        [_clients removeAllObjects];
    }
    for (GCDAsyncSocket *client in clients) {
        [client setDelegate:nil delegateQueue:NULL];
        [client disconnect];
    }

    [self appendLine:@"Server stopped" kind:ServerLogKindInfo];
    [self postChange];
}

#pragma mark - Sending

- (NSUInteger)sendLine:(NSString *)line {
    NSArray<GCDAsyncSocket *> *clients;
    @synchronized (_clients) {
        clients = [_clients copy];
    }
    if (clients.count == 0) {
        [self appendLine:@"No clients connected, message not sent" kind:ServerLogKindError];
        return 0;
    }

    NSData *data = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    for (GCDAsyncSocket *client in clients) {
        [client writeData:data withTimeout:-1 tag:0];
    }
    [self appendLine:[NSString stringWithFormat:@"To %lu client%@: %@", (unsigned long)clients.count,
                      clients.count == 1 ? @"" : @"s", line]
                kind:ServerLogKindSent];
    return clients.count;
}

#pragma mark - Log

- (void)clearLog {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_log replaceCharactersInRange:NSMakeRange(0, self->_log.length) withString:@""];
        [NSNotificationCenter.defaultCenter postNotificationName:ServerSessionDidUpdateLogNotification object:self];
    });
}

- (void)appendLine:(NSString *)text kind:(ServerLogKind)kind {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSFont *font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
        NSColor *color;
        switch (kind) {
            case ServerLogKindReceived: color = NSColor.labelColor; break;
            case ServerLogKindSent: color = NSColor.controlAccentColor; break;
            case ServerLogKindError: color = NSColor.systemRedColor; break;
            default: color = NSColor.secondaryLabelColor; break;
        }

        NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];
        NSString *stamp = [[self->_timeFormatter stringFromDate:NSDate.date] stringByAppendingString:@"  "];
        [line appendAttributedString:[[NSAttributedString alloc] initWithString:stamp attributes:@{
            NSFontAttributeName: font, NSForegroundColorAttributeName: NSColor.tertiaryLabelColor }]];
        [line appendAttributedString:[[NSAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"] attributes:@{
            NSFontAttributeName: font, NSForegroundColorAttributeName: color }]];

        [self->_log beginEditing];
        [self->_log appendAttributedString:line];
        if (self->_log.length > kMaxLogLength) {
            NSUInteger cut = self->_log.length - (kMaxLogLength * 8 / 10);
            NSRange newline = [self->_log.string rangeOfString:@"\n" options:0
                                                         range:NSMakeRange(cut, self->_log.length - cut)];
            if (newline.location != NSNotFound) cut = NSMaxRange(newline);
            [self->_log deleteCharactersInRange:NSMakeRange(0, cut)];
        }
        [self->_log endEditing];
        [NSNotificationCenter.defaultCenter postNotificationName:ServerSessionDidUpdateLogNotification object:self];
    });
}

- (void)postChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:ServerSessionDidChangeNotification object:self];
    });
}

#pragma mark - GCDAsyncSocketDelegate (serial queue)

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    if (sock != _listenSocket) {
        [newSocket disconnect];
        return;
    }
    NSString *peer = [NSString stringWithFormat:@"%@:%hu", newSocket.connectedHost, newSocket.connectedPort];
    newSocket.userData = peer;
    @synchronized (_clients) {
        [_clients addObject:newSocket];
    }
    [self appendLine:[NSString stringWithFormat:@"Client connected: %@", peer] kind:ServerLogKindInfo];
    [self postChange];
    [newSocket readDataToData:_lineDelimiter withTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) {
        text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    }
    text = [text stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet];
    [self appendLine:[NSString stringWithFormat:@"[%@] %@", sock.userData, text] kind:ServerLogKindReceived];
    [sock readDataToData:_lineDelimiter withTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (sock == _listenSocket) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_listenSocket == sock) {
                [self stop];
                [self appendLine:[NSString stringWithFormat:@"Listener closed: %@", err.localizedDescription ?: @"unknown reason"]
                            kind:ServerLogKindError];
            }
        });
        return;
    }

    BOOL known;
    @synchronized (_clients) {
        known = [_clients containsObject:sock];
        [_clients removeObject:sock];
    }
    if (known) {
        [self appendLine:[NSString stringWithFormat:@"Client disconnected: %@", sock.userData ?: @"unknown"]
                    kind:ServerLogKindInfo];
        [self postChange];
    }
}

@end
