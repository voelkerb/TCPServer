//
//  ServerDetailViewController.m
//  TCPServer
//

#import "ServerDetailViewController.h"

// One spacing scale for the whole pane keeps button padding consistent.
static const CGFloat kOuterMargin = 16;
static const CGFloat kCardSpacing = 12;
static const CGFloat kCardInset = 16;
static const CGFloat kItemSpacing = 12;
static const CGFloat kCardRadius = 22;

static NSView *MakeCard(NSView *content) {
    content.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(macOS 26.0, *)) {
        NSGlassEffectView *glass = [[NSGlassEffectView alloc] init];
        glass.cornerRadius = kCardRadius;
        glass.contentView = content;
        glass.translatesAutoresizingMaskIntoConstraints = NO;
        return glass;
    }
    NSVisualEffectView *effect = [[NSVisualEffectView alloc] init];
    effect.material = NSVisualEffectMaterialContentBackground;
    effect.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    effect.state = NSVisualEffectStateActive;
    effect.wantsLayer = YES;
    effect.layer.cornerRadius = kCardRadius;
    effect.layer.masksToBounds = YES;
    effect.translatesAutoresizingMaskIntoConstraints = NO;
    [effect addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:effect.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:effect.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:effect.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:effect.bottomAnchor],
    ]];
    return effect;
}

// Wraps a stack in a padded container so every card uses the same insets.
static NSView *PaddedContainer(NSView *stack) {
    NSView *container = [[NSView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:kCardInset],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-kCardInset],
        [stack.topAnchor constraintEqualToAnchor:container.topAnchor constant:kCardInset],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-kCardInset],
    ]];
    return container;
}

static NSButton *MakeButton(NSString *title, NSString *symbol, id target, SEL action) {
    NSButton *button = [NSButton buttonWithTitle:title target:target action:action];
    if (symbol) {
        button.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:title];
        button.imagePosition = NSImageLeading;
    }
    button.controlSize = NSControlSizeLarge;
    if (@available(macOS 26.0, *)) {
        button.bezelStyle = NSBezelStyleGlass;
    } else {
        button.bezelStyle = NSBezelStyleRounded;
    }
    [button setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [button setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    return button;
}

static NSStackView *MakeRow(NSArray<NSView *> *views) {
    NSStackView *row = [NSStackView stackViewWithViews:views];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = kItemSpacing;
    return row;
}

@interface ServerDetailViewController () <NSTextFieldDelegate> {
    NSStackView *_content;
    NSTextField *_emptyLabel;

    NSTextField *_nameField;
    NSImageView *_statusDot;
    NSTextField *_statusLabel;
    NSTextField *_portField;
    NSButton *_toggleButton;

    NSTextField *_clientsLabel;
    NSSwitch *_followSwitch;
    NSButton *_clearButton;
    NSScrollView *_scrollView;
    NSTextView *_textView;
    NSTextStorage *_emptyStorage;

    NSTextField *_messageField;
    NSButton *_sendButton;
}
@end

@implementation ServerDetailViewController

- (void)loadView {
    self.view = [[NSView alloc] init];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSView *header = [self buildHeaderCard];
    NSView *activity = [self buildActivityCard];
    NSView *composer = [self buildComposerCard];

    _content = [NSStackView stackViewWithViews:@[header, activity, composer]];
    _content.orientation = NSUserInterfaceLayoutOrientationVertical;
    _content.alignment = NSLayoutAttributeWidth;
    _content.spacing = kCardSpacing;
    _content.translatesAutoresizingMaskIntoConstraints = NO;
    // Activity absorbs all extra height so top and bottom margins stay equal.
    _content.distribution = NSStackViewDistributionFill;
    [header setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
    [composer setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
    [activity setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
    [self.view addSubview:_content];
    for (NSView *card in @[header, activity, composer]) {
        [card.leadingAnchor constraintEqualToAnchor:_content.leadingAnchor].active = YES;
        [card.trailingAnchor constraintEqualToAnchor:_content.trailingAnchor].active = YES;
    }

    _emptyLabel = [NSTextField labelWithString:@"No server selected\nAdd one with the + button."];
    _emptyLabel.alignment = NSTextAlignmentCenter;
    _emptyLabel.font = [NSFont systemFontOfSize:15];
    _emptyLabel.textColor = NSColor.secondaryLabelColor;
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];

    NSLayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_content.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kOuterMargin],
        [_content.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kOuterMargin],
        [_content.topAnchor constraintEqualToAnchor:safe.topAnchor constant:kOuterMargin],
        [_content.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-kOuterMargin],
        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(sessionDidChange:)
                                               name:ServerSessionDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(logDidUpdate:)
                                               name:ServerSessionDidUpdateLogNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(userDidScroll:)
                                               name:NSScrollViewDidLiveScrollNotification object:_scrollView];
    [self refresh];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Building

- (NSView *)buildHeaderCard {
    _nameField = [NSTextField textFieldWithString:@""];
    _nameField.font = [NSFont systemFontOfSize:17 weight:NSFontWeightSemibold];
    _nameField.bezelStyle = NSTextFieldRoundedBezel;
    _nameField.controlSize = NSControlSizeLarge;
    _nameField.editable = YES;
    _nameField.placeholderString = @"Server name";
    [_nameField.widthAnchor constraintGreaterThanOrEqualToConstant:140].active = YES;
    [_nameField.widthAnchor constraintLessThanOrEqualToConstant:260].active = YES;
    _nameField.lineBreakMode = NSLineBreakByTruncatingTail;
    _nameField.delegate = self;
    [_nameField setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    _statusDot = [[NSImageView alloc] init];
    _statusDot.image = [NSImage imageWithSystemSymbolName:@"circle.fill" accessibilityDescription:nil];
    _statusDot.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:8 weight:NSFontWeightRegular];
    _statusLabel = [NSTextField labelWithString:@""];
    _statusLabel.textColor = NSColor.secondaryLabelColor;
    NSStackView *status = MakeRow(@[_statusDot, _statusLabel]);
    status.spacing = 6;

    _statusLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_statusLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSTextField *portCaption = [NSTextField labelWithString:@"Port"];
    portCaption.textColor = NSColor.secondaryLabelColor;
    [portCaption setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterNoStyle;
    formatter.usesGroupingSeparator = NO;
    formatter.allowsFloats = NO;
    formatter.minimum = @1;
    formatter.maximum = @65535;
    _portField = [NSTextField textFieldWithString:@""];
    _portField.formatter = formatter;
    _portField.bezelStyle = NSTextFieldRoundedBezel;
    _portField.controlSize = NSControlSizeLarge;
    _portField.alignment = NSTextAlignmentCenter;
    _portField.placeholderString = @"2000";
    _portField.delegate = self;
    _portField.target = self;
    _portField.action = @selector(toggleServer:);
    [_portField.widthAnchor constraintEqualToConstant:88].active = YES;
    [_portField setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

    _toggleButton = MakeButton(@"Start", @"play.fill", self, @selector(toggleServer:));
    [_toggleButton.widthAnchor constraintGreaterThanOrEqualToConstant:104].active = YES;

    NSView *spacer = [[NSView alloc] init];
    [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [spacer setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView *row = MakeRow(@[_nameField, status, spacer, portCaption, _portField, _toggleButton]);
    return MakeCard(PaddedContainer(row));
}

- (NSView *)buildActivityCard {
    NSTextField *title = [NSTextField labelWithString:@"Activity"];
    title.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];

    _clientsLabel = [NSTextField labelWithString:@""];
    _clientsLabel.textColor = NSColor.secondaryLabelColor;

    NSTextField *followCaption = [NSTextField labelWithString:@"Auto-scroll"];
    followCaption.textColor = NSColor.secondaryLabelColor;
    _followSwitch = [[NSSwitch alloc] init];
    _followSwitch.state = NSControlStateValueOn;
    _followSwitch.target = self;
    _followSwitch.action = @selector(followChanged:);

    _clearButton = MakeButton(@"Clear", @"trash", self, @selector(clearLog:));

    NSView *spacer = [[NSView alloc] init];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView *toolbar = MakeRow(@[title, _clientsLabel, spacer, followCaption, _followSwitch, _clearButton]);

    // TextKit 1 stack so each session's storage can be swapped in without copying.
    _emptyStorage = [[NSTextStorage alloc] init];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [_emptyStorage addLayoutManager:layoutManager];
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:NSMakeSize(400, CGFLOAT_MAX)];
    container.widthTracksTextView = YES;
    [layoutManager addTextContainer:container];

    _textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200) textContainer:container];
    _textView.editable = NO;
    _textView.selectable = YES;
    _textView.drawsBackground = NO;
    _textView.textContainerInset = NSMakeSize(10, 10);
    _textView.minSize = NSMakeSize(0, 0);
    _textView.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    _textView.verticallyResizable = YES;
    _textView.horizontallyResizable = NO;
    _textView.autoresizingMask = NSViewWidthSizable;
    _textView.usesFindBar = YES;

    _scrollView = [[NSScrollView alloc] init];
    _scrollView.documentView = _textView;
    _scrollView.hasVerticalScroller = YES;
    _scrollView.drawsBackground = NO;
    _scrollView.borderType = NSNoBorder;

    // Inner well keeps log text readable on top of glass.
    NSBox *well = [[NSBox alloc] init];
    well.boxType = NSBoxCustom;
    well.titlePosition = NSNoTitle;
    well.borderWidth = 0;
    well.cornerRadius = 12;
    well.fillColor = [NSColor.textBackgroundColor colorWithAlphaComponent:0.45];
    well.contentViewMargins = NSZeroSize;
    well.contentView = _scrollView;
    [well setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationVertical];
    [well.heightAnchor constraintGreaterThanOrEqualToConstant:160].active = YES;

    NSStackView *column = [NSStackView stackViewWithViews:@[toolbar, well]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeWidth;
    column.spacing = kItemSpacing;
    return MakeCard(PaddedContainer(column));
}

- (NSView *)buildComposerCard {
    _messageField = [NSTextField textFieldWithString:@""];
    _messageField.bezelStyle = NSTextFieldRoundedBezel;
    _messageField.controlSize = NSControlSizeLarge;
    _messageField.placeholderString = @"Message to all connected clients";
    _messageField.target = self;
    _messageField.action = @selector(sendMessage:);
    [_messageField setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    _sendButton = MakeButton(@"Send", @"paperplane.fill", self, @selector(sendMessage:));
    [_sendButton.widthAnchor constraintGreaterThanOrEqualToConstant:104].active = YES;

    NSStackView *row = MakeRow(@[_messageField, _sendButton]);
    return MakeCard(PaddedContainer(row));
}

#pragma mark - State

- (void)setSession:(ServerSession *)session {
    _session = session;
    if (!self.isViewLoaded) return;
    [self refresh];
    [self attachLog];
}

- (void)refresh {
    ServerSession *session = _session;
    _content.hidden = session == nil;
    _emptyLabel.hidden = session != nil;
    if (!session) return;

    BOOL running = session.running;
    if (![_nameField.currentEditor isKindOfClass:NSText.class]) {
        _nameField.stringValue = session.name;
    }
    if (!_portField.currentEditor) {
        _portField.integerValue = session.port;
    }
    _portField.enabled = !running;

    NSUInteger clients = session.clientCount;
    _statusDot.contentTintColor = running ? NSColor.systemGreenColor : NSColor.tertiaryLabelColor;
    _statusLabel.stringValue = running ? @"Listening" : @"Stopped";
    _clientsLabel.stringValue = [NSString stringWithFormat:@"%lu client%@", (unsigned long)clients, clients == 1 ? @"" : @"s"];

    _toggleButton.title = running ? @"Stop" : @"Start";
    _toggleButton.image = [NSImage imageWithSystemSymbolName:(running ? @"stop.fill" : @"play.fill") accessibilityDescription:nil];
    _toggleButton.bezelColor = running ? NSColor.systemRedColor : NSColor.controlAccentColor;

    _messageField.enabled = running;
    _sendButton.enabled = running;
    _sendButton.bezelColor = running ? NSColor.controlAccentColor : nil;
}

- (void)attachLog {
    NSTextStorage *storage = _session ? _session.log : _emptyStorage;
    if (_textView.layoutManager.textStorage != storage) {
        [_textView.layoutManager replaceTextStorage:storage];
    }
    if (_followSwitch.state == NSControlStateValueOn) [self scrollToBottom];
}

- (void)scrollToBottom {
    [_textView scrollRangeToVisible:NSMakeRange(_textView.string.length, 0)];
}

#pragma mark - Notifications

- (void)sessionDidChange:(NSNotification *)note {
    if (note.object == _session) [self refresh];
}

- (void)logDidUpdate:(NSNotification *)note {
    if (note.object == _session && _followSwitch.state == NSControlStateValueOn) {
        [self scrollToBottom];
    }
}

// Scrolling up pauses auto-scroll; returning to the bottom resumes it.
- (void)userDidScroll:(NSNotification *)note {
    CGFloat visibleMax = NSMaxY(_scrollView.contentView.bounds);
    BOOL atBottom = visibleMax >= NSHeight(_textView.frame) - 8;
    _followSwitch.state = atBottom ? NSControlStateValueOn : NSControlStateValueOff;
}

#pragma mark - Actions

- (void)followChanged:(id)sender {
    if (_followSwitch.state == NSControlStateValueOn) [self scrollToBottom];
}

- (void)clearLog:(id)sender {
    [_session clearLog];
}

- (void)toggleServer:(id)sender {
    ServerSession *session = _session;
    if (!session) return;
    if (session.running) {
        [session stop];
        return;
    }

    NSInteger port = _portField.integerValue;
    if (_portField.stringValue.length == 0 || port < 1 || port > 65535) {
        [self presentAlert:@"Invalid Port" text:@"Enter a port number between 1 and 65535."];
        return;
    }
    session.port = (uint16_t)port;

    for (ServerSession *other in [self runningSessionsExcluding:session]) {
        if (other.port == session.port) {
            [self presentAlert:@"Port in Use"
                          text:[NSString stringWithFormat:@"“%@” is already listening on port %ld.", other.name, (long)port]];
            return;
        }
    }

    NSError *error = nil;
    if (![session startWithError:&error]) {
        [self presentAlert:@"Unable to Start Server" text:error.localizedDescription ?: @"Unknown error."];
    }
}

- (NSArray<ServerSession *> *)runningSessionsExcluding:(ServerSession *)excluded {
    NSMutableArray *result = [NSMutableArray array];
    NSArray<ServerSession *> *all = self.allSessionsProvider ? self.allSessionsProvider() : @[];
    for (ServerSession *candidate in all) {
        if (candidate != excluded && candidate.running) [result addObject:candidate];
    }
    return result;
}

- (void)sendMessage:(id)sender {
    NSString *text = _messageField.stringValue;
    if (!_session.running || text.length == 0) return;
    if ([_session sendLine:text] > 0) {
        _messageField.stringValue = @"";
    }
    [self.view.window makeFirstResponder:_messageField];
}

- (void)presentAlert:(NSString *)title text:(NSString *)text {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = title;
    alert.informativeText = text;
    [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    ServerSession *session = _session;
    if (!session) return;

    if (obj.object == _nameField) {
        NSString *name = [_nameField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (name.length > 0) session.name = name;
        _nameField.stringValue = session.name;
    } else if (obj.object == _portField && !session.running) {
        NSInteger port = _portField.integerValue;
        if (port >= 1 && port <= 65535) session.port = (uint16_t)port;
        _portField.integerValue = session.port;
    }
}

@end
