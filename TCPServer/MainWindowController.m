//
//  MainWindowController.m
//  TCPServer
//

#import "MainWindowController.h"
#import "ServerListViewController.h"
#import "ServerDetailViewController.h"

static NSToolbarItemIdentifier const kTitleItem = @"AppTitle";

@interface MainWindowController () <NSToolbarDelegate, ServerListViewControllerDelegate> {
    ServerListViewController *_list;
    ServerDetailViewController *_detail;
}
@end

@implementation MainWindowController

- (instancetype)init {
    NSWindowStyleMask mask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
        NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 980, 640)
                                                   styleMask:mask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"TCP Server";
    window.minSize = NSMakeSize(760, 480);
    window.toolbarStyle = NSWindowToolbarStyleUnified;
    window.releasedWhenClosed = NO;

    self = [super initWithWindow:window];
    if (self) {
        _list = [[ServerListViewController alloc] init];
        _list.delegate = self;
        _detail = [[ServerDetailViewController alloc] init];
        __weak ServerListViewController *weakList = _list;
        _detail.allSessionsProvider = ^NSArray<ServerSession *> * {
            return weakList.sessions ?: @[];
        };

        NSSplitViewController *split = [[NSSplitViewController alloc] init];
        NSSplitViewItem *sidebar = [NSSplitViewItem sidebarWithViewController:_list];
        sidebar.minimumThickness = 210;
        sidebar.maximumThickness = 320;
        NSSplitViewItem *content = [NSSplitViewItem contentListWithViewController:_detail];
        content.minimumThickness = 480;
        [split addSplitViewItem:sidebar];
        [split addSplitViewItem:content];
        window.contentViewController = split;
        [window setContentSize:NSMakeSize(980, 640)];

        NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"MainToolbar"];
        toolbar.delegate = self;
        toolbar.displayMode = NSToolbarDisplayModeIconOnly;
        window.toolbar = toolbar;
        if (@available(macOS 13.0, *)) {
            window.titleVisibility = NSWindowTitleHidden;
        }

        if (![window setFrameUsingName:@"MainWindow"]) [window center];
        window.frameAutosaveName = @"MainWindow";
    }
    return self;
}

- (void)addServer { [_list addServer]; }
- (void)stopAllServers { [_list stopAllServers]; }

- (void)serverList:(ServerListViewController *)list didSelectSession:(ServerSession *)session {
    _detail.session = session;
}

#pragma mark - NSToolbarDelegate

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[NSToolbarToggleSidebarItemIdentifier, NSToolbarSidebarTrackingSeparatorItemIdentifier,
             kTitleItem];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)identifier
 willBeInsertedIntoToolbar:(BOOL)flag {
    if ([identifier isEqualToString:kTitleItem]) {
        NSTextField *title = [NSTextField labelWithString:@"TCP Server"];
        title.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        NSToolbarItem *titleItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        title.translatesAutoresizingMaskIntoConstraints = NO;
        NSView *holder = [[NSView alloc] init];
        [holder addSubview:title];
        [NSLayoutConstraint activateConstraints:@[
            [title.leadingAnchor constraintEqualToAnchor:holder.leadingAnchor constant:8],
            [title.trailingAnchor constraintEqualToAnchor:holder.trailingAnchor],
            [title.centerYAnchor constraintEqualToAnchor:holder.centerYAnchor],
        ]];
        titleItem.view = holder;
        titleItem.bordered = NO;
        return titleItem;
    }
    return nil;
}

@end
