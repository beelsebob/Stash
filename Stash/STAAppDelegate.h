//
//  STAAppDelegate.h
//  Stash
//
//  Created by Thomas Davie on 01/06/2012.
//  Copyright (c) 2012 Thomas Davie. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "STAPreferencesController.h"
#import "STAMainWindowController.h"

@interface STAAppDelegate : NSResponder <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, STAPreferencesDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSMenu *statusMenu;
@property (weak) IBOutlet NSMenuItem *openStashMenuItem;
@property (strong) NSStatusItem *statusItem;
@property (strong) STAPreferencesController *preferencesController;
@property (strong) IBOutlet STAMainWindowController *mainWindowController;

- (IBAction)toggleStashWindow:(id)sender;
- (IBAction)openPreferences:(id)sender;
- (IBAction)quit:(id)sender;

@end
