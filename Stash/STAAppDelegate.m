//
//  STAAppDelegate.m
//  Stash
//
//  Created by Thomas Davie on 01/06/2012.
//  Copyright (c) 2012 Thomas Davie. All rights reserved.
//

#import "STAAppDelegate.h"

#import "STADocSet.h"

#import "STASymbolTableViewCell.h"

NSImage *NSImageFromSTASymbolType(STASymbolType t);
NSImage *NSImageFromSTAPlatform(STAPlatform p);

@interface STAAppDelegate () <NSWindowDelegate>

@property (strong) NSMutableArray *docsets;
@property (copy) NSString *currentSearchString;
@property (strong) NSMutableArray *results;
@property (strong) NSArray *sortedResults;
@property (assign, getter=isFindUIShowing) BOOL findUIShowing;

- (void)readDocsets;
- (void)showFindUI;
- (void)searchAgain:(BOOL)backwards;

@end

@implementation STAAppDelegate

@synthesize window = _window;
@synthesize statusMenu = _statusMenu;
@synthesize openStashMenuItem = _openStashMenuItem;
@synthesize statusItem = _statusItem;
@synthesize resultsTable = _resultsTable;
@synthesize resultWebView = _resultWebView;
@synthesize titleView = _titleView;
@synthesize searchField = _searchField;
@synthesize preferencesController = _preferencesController;

@synthesize docsets = _docsets;
@synthesize currentSearchString = _currentSearchString;
@synthesize results = _results;
@synthesize sortedResults = _sortedResults;

@synthesize findUIShowing = _findUIShowing;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setStatusItem:[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength]];
    [[self statusItem] setMenu:[self statusMenu]];
    [[self statusItem] setTitle:@"Stash"];
    [[self statusItem] setHighlightMode:YES];
    
    [self setPreferencesController:[[STAPreferencesController alloc] initWithNibNamed:@"STAPreferencesController" bundle:nil]];
    [[self preferencesController] setDelegate:self];

    unichar c = [[self preferencesController] keyboardShortcutCharacter];
    [[self openStashMenuItem] setKeyEquivalent:[NSString stringWithCharacters:&c length:1]];
    [[self openStashMenuItem] setKeyEquivalentModifierMask:[[self preferencesController] keyboardShortcutModifierFlags]];
    
    void(^handler)(NSEvent *) = ^(NSEvent *e)
    {
        if (![[self preferencesController] isMonitoringForEvents])
        {
            NSUInteger modifiers = [e modifierFlags] & NSDeviceIndependentModifierFlagsMask;
            NSUInteger desiredModifiers = [[self preferencesController] keyboardShortcutModifierFlags];
            if (modifiers == desiredModifiers && [[e charactersIgnoringModifiers] characterAtIndex:0] == [[self preferencesController] keyboardShortcutCharacter])
            {
                [self toggleStashWindow:self];
            }
        }
    };
    
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSKeyUpMask handler:handler];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyUpMask handler:^ NSEvent * (NSEvent *e) { handler(e); return e; }];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^ NSEvent * (NSEvent *e)
     {
         NSUInteger modifiers = [e modifierFlags] & NSDeviceIndependentModifierFlagsMask;
         if (modifiers == NSCommandKeyMask &&
             ([[e charactersIgnoringModifiers] isEqualToString:@"f"] ||
              ([[e charactersIgnoringModifiers] isEqualToString:@"g"] && [self isFindUIShowing])))
         {
             return nil;
         }
         if (modifiers == (NSCommandKeyMask | NSShiftKeyMask) &&
             [[e charactersIgnoringModifiers] isEqualToString:@"G"] &&
             [self isFindUIShowing])
         {
             return nil;
         }
         return e;
     }];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyUpMask handler:^ NSEvent * (NSEvent *e)
     {
         NSUInteger modifiers = [e modifierFlags] & NSDeviceIndependentModifierFlagsMask;
         if (modifiers == NSCommandKeyMask && [[e charactersIgnoringModifiers] isEqualToString:@"f"])
         {
             if (![self isFindUIShowing])
             {
                 [self showFindUI];
             }
             else
             {
                 [self hideSearchBar:self];
             }
             return nil;
         }
         if (modifiers == NSCommandKeyMask || modifiers == (NSCommandKeyMask | NSShiftKeyMask))
         {
             if (([[e charactersIgnoringModifiers] isEqualToString:@"g"] || [[e charactersIgnoringModifiers] isEqualToString:@"G"]) && [self isFindUIShowing])
             {
                 [self searchAgain:(modifiers & NSShiftKeyMask) == 0 ? YES : NO];
                 return nil;
             }
             
         }
         return e;
     }];
    
    [self readDocsets];
}

- (void)showFindUI
{
    [[self window] makeFirstResponder:[self inPageSearchField]];
    if (![self isFindUIShowing])
    {
        [self setFindUIShowing:YES];
        NSRect currentFrame = [[self resultWebView] frame];
        currentFrame.size.height -= 25.0f;
        [NSAnimationContext runAnimationGroup:^ (NSAnimationContext *ctx)
         {
             [[[self resultWebView] animator] setFrame:currentFrame];
         }
                            completionHandler:^()
        {
            [[self resultWebView] setFrame:currentFrame];
        }];
    }
}

- (IBAction)hideSearchBar:(id)sender
{
    [[self window] makeFirstResponder:[self searchField]];
    if ([self isFindUIShowing])
    {
        [self setFindUIShowing:NO];
        [NSAnimationContext runAnimationGroup:^ (NSAnimationContext *ctx)
         {
             NSRect currentFrame = [[self resultWebView] frame];
             currentFrame.size.height += 25.0f;
             [[[self resultWebView] animator] setFrame:currentFrame];
         }
                            completionHandler:^(){}];
    }
}

- (IBAction)searchWithinPage:(id)sender
{
    [[self resultWebView] searchFor:[[self inPageSearchField] stringValue]
                          direction:YES
                      caseSensitive:NO
                               wrap:YES];
}

- (void)searchAgain:(BOOL)backwards
{
    [[self resultWebView] searchFor:[[self inPageSearchField] stringValue]
                          direction:backwards
                      caseSensitive:NO
                               wrap:YES];
}

- (void)readDocsets
{
    NSError *err;
    NSArray *docsetRoots = [self docsetRoots];
    NSString *pathForArchive = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDirectory, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Stash"];
    BOOL isDir;
    BOOL appSupportDirectoryIsPresent = [[NSFileManager defaultManager] fileExistsAtPath:pathForArchive isDirectory:&isDir];
    if (appSupportDirectoryIsPresent && !isDir)
    {
        NSLog(@"Could not create app support directory – a file is in the way");
        appSupportDirectoryIsPresent = NO;
    }
    else if (!appSupportDirectoryIsPresent)
    {
        BOOL created = [[NSFileManager defaultManager] createDirectoryAtPath:pathForArchive withIntermediateDirectories:YES attributes:nil error:&err];
        if (!created)
        {
            NSLog(@"Could not create app support directory – %@", err);
        }
    }
    
    [self setDocsets:[NSMutableArray arrayWithCapacity:[docsetRoots count]]];
    __block NSUInteger numDocsetsIndexing = 0;
    __block NSUInteger numDocsetsIndexed = 0;
    __block BOOL finishedSearchingForDocsets = NO;
    [[self searchField] setEnabled:NO];
    for (NSString *path in docsetRoots)
    {
        NSString *docsetDirectory = [[[[path stringByAppendingPathComponent:@"Developer"] stringByAppendingPathComponent:@"Shared"] stringByAppendingPathComponent:@"Documentation"] stringByAppendingPathComponent:@"DocSets"];
        for (NSString *docset in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docsetDirectory error:&err])
        {
            STADocSet *indexedDocset = nil;
            NSString *docsetCachePath = [[pathForArchive stringByAppendingPathComponent:docset] stringByAppendingPathExtension:@"stashidx"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:docsetCachePath isDirectory:&isDir])
            {
                indexedDocset = [NSKeyedUnarchiver unarchiveObjectWithFile:docsetCachePath];
                [indexedDocset setCachePath:docsetCachePath];
            }
            if (nil == indexedDocset)
            {
                NSString *docsetPath = [docsetDirectory stringByAppendingPathComponent:docset];
                BOOL docsetExists = [[NSFileManager defaultManager] fileExistsAtPath:docsetPath isDirectory:&isDir];
                if (docsetExists & isDir)
                {
                    numDocsetsIndexing++;
                    indexedDocset = [STADocSet docSetWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@", docsetPath]]
                                                   cachePath:docsetCachePath
                                                 onceIndexed:^(STADocSet *idx)
                                     {
                                         [NSKeyedArchiver archiveRootObject:idx toFile:docsetCachePath];
                                         numDocsetsIndexed++;
                                         if (numDocsetsIndexed == numDocsetsIndexing && finishedSearchingForDocsets)
                                         {
                                             dispatch_async(dispatch_get_main_queue(), ^()
                                                            {
                                                                [[self searchField] setEnabled:YES];
                                                                [[self searchField] selectText:self];
                                                                [[self titleView] setStringValue:@""];
                                                            });
                                         }
                                     }];
                }
            }
            [[self preferencesController] registerDocset:indexedDocset];
            [[self docsets] addObject:indexedDocset];
            if (![[[self preferencesController] enabledDocsets] containsObject:indexedDocset])
            {
                [indexedDocset unload];
            }
        }
    }
    finishedSearchingForDocsets = YES;
    if (numDocsetsIndexed == numDocsetsIndexing)
    {
        [[self searchField] setEnabled:YES];
    }
    else
    {
        [[self titleView] setStringValue:@"Stash is Indexing, Please Wait..."];
    }
}

- (NSArray *)docsetRoots
{
    NSMutableArray *docsetRoots = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask | NSLocalDomainMask | NSSystemDomainMask, YES) mutableCopy];
    return [docsetRoots copy];
}

- (IBAction)toggleStashWindow:(id)sender
{
    if ([[self window] isVisible])
    {
        [[self window] close];
        [[NSApplication sharedApplication] hide:self];
    }
    else
    {
        [[self window] makeKeyAndOrderFront:self];
        [[self window] setNextResponder:self];
        [[self window] makeFirstResponder:[self searchField]];
        NSLog(@"Selecting text");
        [[self searchField] selectText:self];
        [NSApp activateIgnoringOtherApps:YES];
    }
}

- (void)cancelOperation:(id)sender
{
    [self toggleStashWindow:sender];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    [[self window] close];
}

- (IBAction)search:(id)sender
{
    NSString *searchString = [[[self searchField] stringValue] lowercaseString];
    [self hideSearchBar:self];
    [self setCurrentSearchString:searchString];
    [self setResults:[NSMutableArray array]];
    [[self resultsTable] deselectAll:self];
    for (STADocSet *docSet in [[self preferencesController] enabledDocsets])
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^()
                       {
                           @autoreleasepool
                           {
                               [docSet search:searchString
                                       method:[[self searchMethodSelector] selectedRow] == 0 ? STASearchMethodPrefix : STASearchMethodContains
                                     onResult:^(STASymbol *symbol)
                                {
                                    dispatch_sync(dispatch_get_main_queue(), ^()
                                                  {
                                                      if ([searchString isEqualToString:[self currentSearchString]])
                                                      {
                                                          [[self results] addObject:symbol];
                                                          [self setSortedResults:[[self results] sortedArrayUsingSelector:@selector(compare:)]];
                                                          [[self resultsTable] reloadData];
                                                          if ([[self resultsTable] selectedRow] == -1)
                                                          {
                                                              [[self resultsTable] selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                                                          }
                                                          [self tableViewSelectionDidChange:nil];
                                                      }
                                                  });
                                }];
                           }
                       });
    }
}

- (IBAction)openPreferences:(id)sender
{
    [[self preferencesController] showWindow];
}

- (IBAction)quit:(id)sender
{
    [NSApp terminate:sender];
}

- (IBAction)setSearchMethod:(id)sender
{
    [self search:sender];
}

#pragma mark - Table View Data Source
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [[self sortedResults] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return row < [[self sortedResults] count] ? [[[self sortedResults] objectAtIndex:row] symbolName] : @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSUInteger row = [[self resultsTable] selectedRow];
    if (row < [[self sortedResults] count])
    {
        STASymbol *symbol = [[self sortedResults] objectAtIndex:row];
        NSURLRequest *request = [NSURLRequest requestWithURL:[symbol url]];
        [[[self resultWebView] mainFrame] loadRequest:request];
    }
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return [[STASymbolTableViewCell alloc] init];
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    [cell setSymbolTypeImage:NSImageFromSTASymbolType([[[self sortedResults] objectAtIndex:row] symbolType])];
    [cell setPlatformImage:NSImageFromSTAPlatform([[[[self sortedResults] objectAtIndex:row] docSet] platform])];
}

#pragma mark - Prefs Delegate
- (void)preferencesControllerDidUpdateSelectedDocsets:(STAPreferencesController *)prefsController
{
    for (STADocSet *docset in [self docsets])
    {
        if (![[prefsController enabledDocsets] containsObject:docset])
        {
            [docset unload];
        }
    }
}

- (void)preferencesControllerDidUpdateMenuShortcut:(STAPreferencesController *)prefsController
{
    unichar c = [[self preferencesController] keyboardShortcutCharacter];
    [[self openStashMenuItem] setKeyEquivalent:[NSString stringWithCharacters:&c length:1]];
    [[self openStashMenuItem] setKeyEquivalentModifierMask:[[self preferencesController] keyboardShortcutModifierFlags]];
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
    [[self titleView] setStringValue:title];
}

@end

NSImage *NSImageFromSTAPlatform(STAPlatform p)
{
    switch (p)
    {
        case STAPlatformIOS:
            return [NSImage imageNamed:@"iOS"];
        case STAPlatformMacOS:
            return [NSImage imageNamed:@"MacOS"];
        default:
            return nil;
    }
}

NSImage *NSImageFromSTASymbolType(STASymbolType t)
{
    switch (t)
    {
        case STASymbolTypeFunction:
            return [NSImage imageNamed:@"Function"];
        case STASymbolTypeMacro:
            return [NSImage imageNamed:@"Macro"];
        case STASymbolTypeTypeDefinition:
            return [NSImage imageNamed:@"Typedef"];
        case STASymbolTypeClass:
            return [NSImage imageNamed:@"Class"];
        case STASymbolTypeInterface:
            return [NSImage imageNamed:@"Protocol"];
        case STASymbolTypeCategory:
            return [NSImage imageNamed:@"Category"];
        case STASymbolTypeClassMethod:
            return [NSImage imageNamed:@"Method"];
        case STASymbolTypeClassConstant:
            return nil;
        case STASymbolTypeInstanceMethod:
            return [NSImage imageNamed:@"Method"];
        case STASymbolTypeInstanceProperty:
            return [NSImage imageNamed:@"Property"];
        case STASymbolTypeInterfaceMethod:
            return [NSImage imageNamed:@"Method"];
        case STASymbolTypeInterfaceClassMethod:
            return [NSImage imageNamed:@"Method"];
        case STASymbolTypeInterfaceProperty:
            return [NSImage imageNamed:@"Property"];
        case STASymbolTypeEnumerationConstant:
            return [NSImage imageNamed:@"Enum"];
        case STASymbolTypeData:
            return [NSImage imageNamed:@"Value"];
        default:
            return nil;
    }
}