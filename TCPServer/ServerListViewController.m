//
//  ServerListViewController.m
//  TCPServer
//

#import "ServerListViewController.h"

static NSString *const kServersDefaultsKey = @"Servers";
static const uint16_t kDefaultFirstPort = 2000;

@interface ServerCellView : NSTableCellView
@property (nonatomic, strong) NSTextField *subtitleField;
@property (nonatomic, strong) NSButton *trashButton;
@property (nonatomic, copy) void (^onDelete)(void);
@end

@implementation ServerCellView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        NSImageView *icon = [[NSImageView alloc] init];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightRegular];

        NSTextField *title = [NSTextField labelWithString:@""];
        title.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        title.lineBreakMode = NSLineBreakByTruncatingTail;
        title.editable = YES;
        title.placeholderString = @"Server name";

        NSTextField *subtitle = [NSTextField labelWithString:@""];
        subtitle.font = [NSFont systemFontOfSize:11];
        subtitle.textColor = NSColor.secondaryLabelColor;
        subtitle.lineBreakMode = NSLineBreakByTruncatingTail;

        NSStackView *texts = [NSStackView stackViewWithViews:@[title, subtitle]];
        texts.orientation = NSUserInterfaceLayoutOrientationVertical;
        texts.alignment = NSLayoutAttributeLeading;
        texts.spacing = 1;
        texts.translatesAutoresizingMaskIntoConstraints = NO;

        [self addSubview:icon];
        [self addSubview:texts];
        [NSLayoutConstraint activateConstraints:@[
            [icon.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
            [icon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [icon.widthAnchor constraintEqualToConstant:18],
            [texts.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:8],
                        [texts.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];

        NSButton *trash = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"xmark" accessibilityDescription:@"Remove Server"]
                                             target:self action:@selector(trashClicked:)];
        trash.bordered = NO;
        trash.toolTip = @"Remove Server";
        trash.contentTintColor = NSColor.secondaryLabelColor;
        trash.imageScaling = NSImageScaleProportionallyDown;
        trash.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:trash];
        [NSLayoutConstraint activateConstraints:@[
            [trash.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [trash.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [trash.widthAnchor constraintEqualToConstant:18],
            [trash.heightAnchor constraintEqualToConstant:18],
        ]];
        [trash setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
        self.trashButton = trash;
        [texts.trailingAnchor constraintLessThanOrEqualToAnchor:trash.leadingAnchor constant:-4].active = YES;

        self.imageView = icon;
        self.textField = title;
        self.subtitleField = subtitle;
    }
    return self;
}

- (void)trashClicked:(id)sender {
    if (self.onDelete) self.onDelete();
}

@end

@interface ServerListViewController () <NSTableViewDataSource, NSTableViewDelegate> {
    NSMutableArray<ServerSession *> *_sessions;
    NSTableView *_tableView;
}
@end

@implementation ServerListViewController

- (NSArray<ServerSession *> *)sessions {
    return _sessions;
}

- (void)loadView {
    _tableView = [[NSTableView alloc] init];
    _tableView.style = NSTableViewStyleFullWidth;
    _tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    _tableView.intercellSpacing = NSZeroSize;
    _tableView.backgroundColor = NSColor.clearColor;
    _tableView.headerView = nil;
    _tableView.rowHeight = 44;
    _tableView.allowsEmptySelection = YES;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"server"];
    column.resizingMask = NSTableColumnAutoresizingMask;
    [_tableView addTableColumn:column];

    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.documentView = _tableView;
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;
    scroll.automaticallyAdjustsContentInsets = YES;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *add = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:@"Add Server"]
                                       target:self action:@selector(addServerClicked:)];
    add.toolTip = @"Add Server";
    add.controlSize = NSControlSizeLarge;
    if (@available(macOS 26.0, *)) {
        add.bezelStyle = NSBezelStyleGlass;
    } else {
        add.bezelStyle = NSBezelStyleRounded;
    }
    add.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *container = [[NSView alloc] init];
    [container addSubview:scroll];
    [container addSubview:add];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:container.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:add.topAnchor constant:-8],
        [add.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:12],
        [add.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-12],
    ]];
    self.view = container;
}

- (void)addServerClicked:(id)sender { [self addServer]; }

- (void)viewDidLoad {
    [super viewDidLoad];

    _sessions = [[NSMutableArray alloc] init];
    for (NSDictionary *entry in [NSUserDefaults.standardUserDefaults arrayForKey:kServersDefaultsKey]) {
        ServerSession *session = [[ServerSession alloc] initWithDictionary:entry];
        if (session) [_sessions addObject:session];
    }
    if (_sessions.count == 0) {
        [_sessions addObject:[self makeDefaultSession]];
    }
    [_tableView reloadData];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(sessionDidChange:)
                                               name:ServerSessionDidChangeNotification
                                             object:nil];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    if (_tableView.selectedRow < 0 && _sessions.count > 0) {
        [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Model

- (nullable ServerSession *)selectedSession {
    NSInteger row = _tableView.selectedRow;
    return (row >= 0 && row < (NSInteger)_sessions.count) ? _sessions[row] : nil;
}

- (ServerSession *)makeDefaultSession {
    NSUInteger number = 1;
    uint16_t port = kDefaultFirstPort;
    while (YES) {
        BOOL nameTaken = NO, portTaken = NO;
        NSString *name = [NSString stringWithFormat:@"Server %lu", (unsigned long)number];
        for (ServerSession *session in _sessions) {
            nameTaken |= [session.name isEqualToString:name];
            portTaken |= session.port == port;
        }
        if (nameTaken) { number++; continue; }
        if (portTaken) { port++; continue; }
        return [[ServerSession alloc] initWithName:name port:port];
    }
}

- (void)save {
    NSMutableArray *entries = [NSMutableArray array];
    for (ServerSession *session in _sessions) {
        [entries addObject:session.dictionaryRepresentation];
    }
    [NSUserDefaults.standardUserDefaults setObject:entries forKey:kServersDefaultsKey];
}

- (void)addServer {
    ServerSession *session = [self makeDefaultSession];
    [_sessions addObject:session];
    NSInteger row = (NSInteger)_sessions.count - 1;
    [_tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation:NSTableViewAnimationSlideDown];
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [_tableView scrollRowToVisible:row];
    [self save];
}

- (void)removeSelectedServer {
    ServerSession *session = self.selectedSession;
    if (session) [self confirmRemoveSession:session];
}

- (void)confirmRemoveSession:(ServerSession *)session {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Remove “%@”?", session.name];
    alert.informativeText = session.running
        ? @"The server is running. Removing it disconnects all clients."
        : @"This server and its settings will be deleted.";
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.buttons.firstObject.hasDestructiveAction = YES;
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) [self removeSession:session];
    }];
}

- (void)removeSession:(ServerSession *)session {
    NSInteger row = (NSInteger)[_sessions indexOfObject:session];
    if (row == NSNotFound) return;
    [session stop];
    [_sessions removeObjectAtIndex:row];
    [_tableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation:NSTableViewAnimationSlideUp];
    if (_sessions.count > 0) {
        NSInteger next = MIN(row, (NSInteger)_sessions.count - 1);
        [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:next] byExtendingSelection:NO];
    } else {
        [self.delegate serverList:self didSelectSession:nil];
    }
    [self save];
}

- (void)stopAllServers {
    for (ServerSession *session in _sessions) [session stop];
}

- (void)sessionDidChange:(NSNotification *)note {
    NSInteger row = (NSInteger)[_sessions indexOfObject:note.object];
    if (row == NSNotFound) return;
    [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                          columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    [self save];
}

#pragma mark - NSTableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)_sessions.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    ServerCellView *cell = [tableView makeViewWithIdentifier:@"ServerCell" owner:self];
    if (!cell) {
        cell = [[ServerCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = @"ServerCell";
    }
    ServerSession *session = _sessions[row];
    cell.textField.stringValue = session.name;
    cell.textField.delegate = self;
    __weak typeof(self) weakSelf = self;
    __weak ServerSession *weakSession = session;
    cell.onDelete = ^{ if (weakSession) [weakSelf confirmRemoveSession:weakSession]; };

    NSString *state;
    if (session.running) {
        NSUInteger clients = session.clientCount;
        state = [NSString stringWithFormat:@"Port %hu · %lu client%@", session.port,
                 (unsigned long)clients, clients == 1 ? @"" : @"s"];
    } else {
        state = [NSString stringWithFormat:@"Port %hu · Stopped", session.port];
    }
    cell.subtitleField.stringValue = state;

    cell.imageView.image = [NSImage imageWithSystemSymbolName:(session.running ? @"antenna.radiowaves.left.and.right" : @"circle.dashed")
                                      accessibilityDescription:session.running ? @"Running" : @"Stopped"];
    cell.imageView.contentTintColor = session.running ? NSColor.systemGreenColor : NSColor.tertiaryLabelColor;
    return cell;
}

// Inline rename: click the selected row's name.
- (void)controlTextDidEndEditing:(NSNotification *)obj {
    NSTextField *field = obj.object;
    NSInteger row = [_tableView rowForView:field];
    if (row < 0 || row >= (NSInteger)_sessions.count) return;
    ServerSession *session = _sessions[row];
    NSString *name = [field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (name.length > 0) session.name = name;
    field.stringValue = session.name;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self.delegate serverList:self didSelectSession:self.selectedSession];
}

@end
