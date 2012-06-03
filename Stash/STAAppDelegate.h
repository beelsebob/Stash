//
//  STAAppDelegate.h
//  Stash
//
//  Created by Thomas Davie on 01/06/2012.
//  Copyright (c) 2012 Thomas Davie. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface STAAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSMenu *statusMenu;
@property (strong) NSStatusItem *statusItem;
@property (strong) IBOutlet NSTableView *resultsTable;
@property (strong) IBOutlet WebView *resultWebView;
@property (strong) IBOutlet NSTextField *titleView;
@property (strong) IBOutlet NSSearchField *searchField;

- (IBAction)toggleStashWindow:(id)sender;
- (IBAction)search:(id)sender;

@end
