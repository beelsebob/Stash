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

@interface STAAppDelegate : NSResponder <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, STAPreferencesDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSMenu *statusMenu;
@property (weak) IBOutlet NSMenuItem *openStashMenuItem;
@property (strong) NSStatusItem *statusItem;
@property (strong) IBOutlet NSTableView *resultsTable;
@property (strong) IBOutlet WebView *resultWebView;
@property (strong) IBOutlet NSTextField *titleView;
@property (strong) IBOutlet NSSearchField *searchField;
@property (strong) STAPreferencesController *preferencesController;
@property (weak) IBOutlet NSMatrix *searchMethodSelector;
@property (weak) IBOutlet NSSearchField *inPageSearchField;
@property (weak) IBOutlet NSTableView *indexingDocsetsView;
@property (weak) IBOutlet NSScrollView *indexingDocsetsContainer;
@property (weak) IBOutlet NSView *docsetsNotFoundView;

- (IBAction)toggleStashWindow:(id)sender;
- (IBAction)search:(id)sender;
- (IBAction)openPreferences:(id)sender;
- (IBAction)quit:(id)sender;
- (IBAction)setSearchMethod:(id)sender;
- (IBAction)hideSearchBar:(id)sender;
- (IBAction)showFindUI;
- (IBAction)searchWithinPage:(id)sender;
- (IBAction)addDocumentation:(id)sender;

@end
