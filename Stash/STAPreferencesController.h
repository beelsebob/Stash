//
//  STAPreferencesController.h
//  Stash
//
//  Created by Thomas Davie on 04/06/2012.
//  Copyright (c) 2012 Hunted Cow Studios. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STADocSet.h"

@interface STAPreferencesController : NSObject

@property (strong) IBOutlet NSWindow *window;
@property (readonly) NSArray *enabledDocsets;
@property (readonly) NSUInteger keyboardShortcutModifierFlags;
@property (readonly) unichar keyboardShortcutCharacter;
@property (strong) IBOutlet NSButton *shortcutButton;
@property (strong) IBOutlet NSTextField *shortcutText;
@property (strong) IBOutlet NSScrollView *docsetTable;
@property (readonly) BOOL isMonitoringForEvents;

- (id)initWithNibNamed:(NSString *)nibName bundle:(NSBundle *)bundle;

- (void)showWindow;

- (void)registerDocset:(STADocSet *)docset;

- (IBAction)changeShortcut:(id)sender;

@end
