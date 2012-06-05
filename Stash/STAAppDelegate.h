//
//  STAAppDelegate.h
//  Stash
//
//  Created by Thomas Davie on 01/06/2012.
//  Copyright (c) 2012 Thomas Davie. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "STAPreferencesController.h"

@interface STAAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, STAPreferencesDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSMenu *statusMenu;
@property (strong) NSStatusItem *statusItem;
@property (strong) IBOutlet NSTableView *resultsTable;
@property (strong) IBOutlet WebView *resultWebView;
@property (strong) IBOutlet NSTextField *titleView;
@property (strong) IBOutlet NSSearchField *searchField;
@property (strong) STAPreferencesController *preferencesController;

- (IBAction)toggleStashWindow:(id)sender;
- (IBAction)search:(id)sender;
- (IBAction)openPreferences:(id)sender;
- (IBAction)quit:(id)sender;

@end
