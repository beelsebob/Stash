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

@interface STAAppDelegate () <NSWindowDelegate>

@property (strong) NSMutableArray *docsets;
@property (copy) NSString *currentSearchString;
@property (strong) NSMutableArray *results;
@property (strong) NSArray *sortedResults;

- (void)readDocsets;

@end

@implementation STAAppDelegate

@synthesize window = _window;
@synthesize statusMenu = _statusMenu;
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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setStatusItem:[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength]];
    [[self statusItem] setMenu:[self statusMenu]];
    [[self statusItem] setTitle:@"Stash"];
    [[self statusItem] setHighlightMode:YES];
    
    [self setPreferencesController:[[STAPreferencesController alloc] initWithNibNamed:@"STAPreferencesController" bundle:nil]];
    
    void(^handler)(NSEvent *) = ^(NSEvent *e)
    {
        if (![[self preferencesController] isMonitoringForEvents])
        {
            NSUInteger modifiers = [e modifierFlags];
            NSUInteger desiredModifiers = [[self preferencesController] keyboardShortcutModifierFlags];
            if ((modifiers & desiredModifiers) == desiredModifiers && [[e charactersIgnoringModifiers] characterAtIndex:0] == [[self preferencesController] keyboardShortcutCharacter])
            {
                [self toggleStashWindow:self];
            }
        }
    };
    
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSKeyUpMask handler:handler];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyUpMask handler:^ NSEvent * (NSEvent *e) { handler(e); return e; }];
    
    [self readDocsets];
}

- (void)readDocsets
{
    NSError *err;
    NSArray *libraryDirectories = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask | NSLocalDomainMask | NSSystemDomainMask, YES);
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
    
    [self setDocsets:[NSMutableArray arrayWithCapacity:[libraryDirectories count]]];
    __block NSUInteger numDocsetsIndexing = 0;
    __block NSUInteger numDocsetsIndexed = 0;
    __block BOOL finishedSearchingForDocsets = NO;
    [[self searchField] setEnabled:NO];
    for (NSString *path in libraryDirectories)
    {
        NSString *docsetDirectory = [[[path stringByAppendingPathComponent:@"Developer"] stringByAppendingPathComponent:@"Documentation"] stringByAppendingPathComponent:@"DocSets"];
        for (NSString *docset in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docsetDirectory error:&err])
        {
            STADocSet *indexedDocset = nil;
            NSString *docsetCachePath = [[pathForArchive stringByAppendingPathComponent:docset] stringByAppendingPathExtension:@"stashidx"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:docsetCachePath isDirectory:&isDir])
            {
                indexedDocset = [NSKeyedUnarchiver unarchiveObjectWithFile:docsetCachePath];
            }
            if (nil == indexedDocset)
            {
                numDocsetsIndexing++;
                indexedDocset = [STADocSet docSetWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@", [docsetDirectory stringByAppendingPathComponent:docset]]]
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
            [[self preferencesController] registerDocset:indexedDocset];
            [[self docsets] addObject:indexedDocset];
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

- (IBAction)toggleStashWindow:(id)sender
{
    if ([[self window] isVisible])
    {
        [[self window] close];
    }
    else
    {
        [[self window] makeKeyAndOrderFront:self];
        [[self searchField] selectText:self];
        [NSApp activateIgnoringOtherApps:YES];
    }
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    [[self window] close];
}

- (IBAction)search:(id)sender
{
    NSString *searchString = [[sender stringValue] lowercaseString];
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
        [[self titleView] setStringValue:[symbol symbolName]];
    }
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return [[STASymbolTableViewCell alloc] init];
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    [cell setImage:NSImageFromSTASymbolType([[[self sortedResults] objectAtIndex:row] symbolType])];
}

@end

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