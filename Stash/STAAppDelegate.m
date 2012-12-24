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

@property (copy) NSArray *indexingDocsets;
@property (copy) NSArray *docsets;
@property (assign,getter=isWaitingForDocsetInput) BOOL waitingForDocsetInput;
@property (copy) NSString *currentSearchString;
@property (strong) NSMutableArray *results;
@property (strong) NSMutableArray *sortedResults;
@property (assign, getter=isFindUIShowing) BOOL findUIShowing;
@property (weak) NSSearchField *selectedSearchField;

- (void)readDocsetsWithContinuation:(void(^)(void))cont;
- (void)showFindUI;
- (void)searchAgain:(BOOL)backwards;

@end

@implementation STAAppDelegate
{
    NSMutableArray *_indexingDocsets;
    NSMutableArray *_docsets;
    dispatch_queue_t _docsetArrayEditingQueue;
}

- (NSArray *)indexingDocsets
{
    return [_indexingDocsets copy];
}

- (void)setIndexingDocsets:(NSArray *)indexingDocsets
{
    if (indexingDocsets != _indexingDocsets)
    {
        _indexingDocsets = [indexingDocsets mutableCopy];
    }
}

- (NSArray *)docsets
{
    return [_docsets copy];
}

- (void)setDocsets:(NSArray *)docsets
{
    if (docsets != _docsets)
    {
        _docsets = [docsets mutableCopy];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _docsetArrayEditingQueue = dispatch_queue_create("org.beelsebob.Stash.docsetArrayEditing", DISPATCH_QUEUE_SERIAL);
    
    [self setPreferencesController:[[STAPreferencesController alloc] initWithNibNamed:@"STAPreferencesController" bundle:nil]];
    [[self preferencesController] setDelegate:self];
    
    STAIconShowingMode mode = [[self preferencesController] iconMode];
    
    if (mode == STAIconShowingModeBoth || mode == STAIconShowingModeMenuBar)
    {
        [self setStatusItem:[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength]];
        [[self statusItem] setMenu:[self statusMenu]];
        [[self statusItem] setTitle:@"Stash"];
        [[self statusItem] setHighlightMode:YES];
    }
    if (mode == STAIconShowingModeBoth || mode == STAIconShowingModeDock)
    {
        [[NSApplication sharedApplication] setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
    
    unichar c = [[self preferencesController] keyboardShortcutCharacter];
    [[self openStashMenuItem] setKeyEquivalent:[NSString stringWithCharacters:&c length:1]];
    [[self openStashMenuItem] setKeyEquivalentModifierMask:[[self preferencesController] keyboardShortcutModifierFlags]];
    
    [[[self resultWebView] preferences] setJavaEnabled:NO];
    [[[self resultWebView] preferences] setJavaScriptEnabled:NO];
    [[[self resultWebView] preferences] setJavaScriptCanOpenWindowsAutomatically:NO];
    [[[self resultWebView] preferences] setPlugInsEnabled:NO];
    
    void(^handler)(NSEvent *) = ^(NSEvent *e)
    {
        if (![[self preferencesController] isMonitoringForEvents] && ![self isWaitingForDocsetInput])
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
 
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^()
                   {
                       [[self searchField] setEnabled:NO];
                       [[self titleView] setStringValue:@"Stash is Loading, Please Wait..."];
                       [self readDocsetsWithContinuation:^()
                        {
                            dispatch_async(dispatch_get_main_queue(), ^()
                                           {
                                               [[self searchField] setEnabled:YES];
                                               [[self searchField] selectText:self];
                                               [[self indexingDocsetsContainer] setHidden:YES];
                                               if ([[self docsets] count] > 0)
                                               {
                                                   [[self titleView] setStringValue:@""];
                                               }
                                               else
                                               {
                                                   [[self titleView] setStringValue:@"Stash Could Not Find Any Documentation"];
                                                   [[self docsetsNotFoundView] setHidden:NO];
                                               }
                                           });
                        }];
                   });
}

- (void)dealloc
{
    dispatch_release(_docsetArrayEditingQueue);
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
    if ([self isFindUIShowing])
    {
        if ([self selectedSearchField] != [self searchField])
        {
            [[self window] makeFirstResponder:[self searchField]];
        }
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

#define STADocumentationBookmarksKey @"DocsBookmarks"

- (IBAction)addDocumentation:(id)sender
{
    [[self docsetsNotFoundView] setHidden:YES];
    NSString *lastRoot = [[self docsetRoots] objectAtIndex:0];
    NSString *lastPath = [[[[lastRoot stringByAppendingPathComponent:@"Developer"] stringByAppendingPathComponent:@"Shared"] stringByAppendingPathComponent:@"Documentation"] stringByAppendingPathComponent:@"DocSets"];
    [self requestAccessToDirectory:lastPath
                      continuation:^(NSURL *selectedRoot)
     {
         dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^()
                        {
                            NSError *err = nil;
                            NSData *bookmark = [selectedRoot bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
                                                      includingResourceValuesForKeys:@[]
                                                                       relativeToURL:nil
                                                                               error:&err];
                            NSArray *documentationBookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey:STADocumentationBookmarksKey];
                            documentationBookmarks = documentationBookmarks ? : @[];
                            documentationBookmarks = [documentationBookmarks containsObject:bookmark] ? documentationBookmarks : [documentationBookmarks arrayByAddingObject:bookmark];
                            [[NSUserDefaults standardUserDefaults] setObject:documentationBookmarks forKey:STADocumentationBookmarksKey];
                            [[NSUserDefaults standardUserDefaults] synchronize];
                        });
     }];
}

- (void)searchAgain:(BOOL)backwards
{
    [[self resultWebView] searchFor:[[self inPageSearchField] stringValue]
                          direction:backwards
                      caseSensitive:NO
                               wrap:YES];
}

- (void)readDocsetsWithContinuation:(void(^)(void))cont
{
    [self setDocsets:@[]];
    [self setIndexingDocsets:@[]];
    
    [self readExistingIndexes];
    dispatch_async(dispatch_get_main_queue(), ^()
                   {
                       [[self titleView] setStringValue:@"Stash is Indexing, Please Wait..."];
                       [[self indexingDocsetsContainer] setHidden:NO];
                       [[self indexingDocsetsView] reloadData];
                   });
    [self refreshExistingBookmarksWithContinuation:^()
     {
         if ([[self docsets] count] == 0)
         {
             NSArray *docsetRoots = [self docsetRoots];
             [self indexDocsetsInRoots:docsetRoots withContinuation:cont];
         }
         else
         {
             cont();
         }
     }];
}

- (void)readExistingIndexes
{
    NSError *err;
    BOOL isDir;
    NSString *pathForArchive = [self pathForArchive];
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
    
    NSArray *appSupportContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pathForArchive error:&err];
    NSMutableArray *docsets = [NSMutableArray array];
    for (NSString *indexPath in appSupportContents)
    {
        if ([[indexPath pathExtension] isEqualToString:@"stashidx"])
        {
            STADocSet *docset = [NSKeyedUnarchiver unarchiveObjectWithFile:[pathForArchive stringByAppendingPathComponent:indexPath]];
            if (nil != docset)
            {
                [docset setCachePath:indexPath];
                [docsets addObject:docset];
                [[self preferencesController] registerDocset:docset];
            }
        }
    }
    [self setDocsets:docsets];
}

- (void)refreshExistingBookmarksWithContinuation:(void(^)(void))cont
{
    NSArray *documentationBookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey:STADocumentationBookmarksKey];
    NSMutableArray *bookmarkURLs = [NSMutableArray arrayWithCapacity:[documentationBookmarks count]];
    for (NSData *bookmark in documentationBookmarks)
    {
        BOOL stale = NO;
        NSError *err;
        NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
                                               options:NSURLBookmarkResolutionWithSecurityScope
                                         relativeToURL:nil
                                   bookmarkDataIsStale:&stale
                                                 error:&err];
        [url startAccessingSecurityScopedResource];
        [bookmarkURLs addObject:url];
    }
    [self indexDocsetsWithPermissionInRoots:bookmarkURLs withContinuation:cont];
}

- (void)indexDocsetsInRoots:(NSArray *)roots withContinuation:(void(^)(void))cont
{
    [self indexDocsetsInRoots:roots index:0 selectedRoots:[NSArray array] withContinuation:cont];
}

- (void)indexDocsetsInRoots:(NSArray *)originalRoots index:(NSUInteger)idx selectedRoots:(NSArray *)selectedRoots withContinuation:(void(^)(void))cont
{
    if (idx < [originalRoots count])
    {
        NSString *lastRoot = [originalRoots objectAtIndex:idx];
        NSString *lastPath = [[[[lastRoot stringByAppendingPathComponent:@"Developer"] stringByAppendingPathComponent:@"Shared"] stringByAppendingPathComponent:@"Documentation"] stringByAppendingPathComponent:@"DocSets"];
        dispatch_async(dispatch_get_main_queue(), ^()
                       {
                           [self requestAccessToDirectory:lastPath
                                             continuation:^(NSURL *selectedRoot)
                            {
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^()
                                               {
                                                   NSError *err = nil;
                                                   NSData *bookmark = [selectedRoot bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
                                                                             includingResourceValuesForKeys:@[]
                                                                                              relativeToURL:nil
                                                                                                      error:&err];
                                                   NSArray *documentationBookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey:STADocumentationBookmarksKey];
                                                   documentationBookmarks = documentationBookmarks ? : @[];
                                                   documentationBookmarks = [documentationBookmarks containsObject:bookmark] ? documentationBookmarks : [documentationBookmarks arrayByAddingObject:bookmark];
                                                   [[NSUserDefaults standardUserDefaults] setObject:documentationBookmarks forKey:STADocumentationBookmarksKey];
                                                   [[NSUserDefaults standardUserDefaults] synchronize];
                                                   
                                                   [self indexDocsetsInRoots:originalRoots index:idx+1 selectedRoots:[selectedRoots arrayByAddingObject:selectedRoot] withContinuation:cont];
                                               });
                            }];
                       });
    }
    else
    {
        [self indexDocsetsWithPermissionInRoots:selectedRoots withContinuation:cont];
    }
}

- (void)indexDocsetsWithPermissionInRoots:(NSArray *)roots withContinuation:(void(^)(void))cont
{
    NSError *err;
    BOOL isDir;
    __block BOOL finishedSearchingForDocsets = NO;
    dispatch_async(dispatch_get_main_queue(), ^()
                   {
                       if (![[self window] isVisible])
                       {
                           [self toggleStashWindow:self];
                       }
                   });
    for (NSURL *root in roots)
    {
        for (NSURL *docsetURL in [[NSFileManager defaultManager] contentsOfDirectoryAtURL:root
                                                               includingPropertiesForKeys:[NSArray array]
                                                                                  options:0
                                                                                    error:&err])
        {
            BOOL docsetExists = [[NSFileManager defaultManager] fileExistsAtPath:[docsetURL path] isDirectory:&isDir];
            if (docsetExists && isDir)
            {
                NSString *docsetCachePath = [[[self pathForArchive] stringByAppendingPathComponent:[docsetURL lastPathComponent]] stringByAppendingPathExtension:@"stashidx"];
                
                NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:docsetCachePath error:&err];
                NSDictionary *docsetAttrs = [docsetURL resourceValuesForKeys:@[NSURLContentModificationDateKey] error:&err];
                if (nil == attrs ||
                    [(NSDate *)docsetAttrs[NSURLContentModificationDateKey] compare:attrs[NSFileModificationDate]] == NSOrderedDescending)
                {
                    STADocSet *docset = [STADocSet docSetWithURL:docsetURL
                                                       cachePath:docsetCachePath
                                                     onceIndexed:^(STADocSet *idx)
                                         {
                                             [NSKeyedArchiver archiveRootObject:idx toFile:docsetCachePath];
                                             dispatch_sync(_docsetArrayEditingQueue, ^()
                                                           {
                                                               [_indexingDocsets removeObjectIdenticalTo:idx];
                                                               [_docsets addObject:idx];
                                                               dispatch_async(dispatch_get_main_queue(), ^()
                                                                              {
                                                                                  [[self indexingDocsetsView] reloadData];
                                                                              });
                                                               if (finishedSearchingForDocsets && [_indexingDocsets count] == 0)
                                                               {
                                                                   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), cont);
                                                               }
                                                           });
                                         }];
                    dispatch_sync(_docsetArrayEditingQueue, ^()
                                  {
                                      if ([_docsets indexOfObjectIdenticalTo:docset] == NSNotFound)
                                      {
                                          [_indexingDocsets addObject:docset];
                                      }
                                  });
                    if (nil != docset)
                    {
                        [[self preferencesController] registerDocset:docset];
                        if (![[[self preferencesController] enabledDocsets] containsObject:docset])
                        {
                            [docset unload];
                        }
                    }
                }
            }
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^()
                   {
                       [[self indexingDocsetsView] reloadData];
                   });
    finishedSearchingForDocsets = YES;
    dispatch_sync(_docsetArrayEditingQueue, ^()
                  {
                      if (finishedSearchingForDocsets && [_indexingDocsets count] == 0)
                      {
                          dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), cont);
                      }
                  });
}

- (NSString *)pathForArchive
{
    return [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDirectory, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Stash"];
}

- (void)requestAccessToDirectory:(NSString *)directory continuation:(void(^)(NSURL *))cont
{
    NSURL *requiredURL = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", directory]];
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [self setWaitingForDocsetInput:YES];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setResolvesAliases:NO];
    [panel setTitle:@"Docsets Directory"];
    [panel setPrompt:@"Choose Docsets"];
    [panel setMessage:@"Stash requires access to Xcode's documentation, please select the DocSets directory."];
    [panel setShowsHiddenFiles:YES];
    [panel setDirectoryURL:requiredURL];
    [panel beginWithCompletionHandler:^ (NSInteger result)
     {
         if (result == NSFileHandlingPanelOKButton)
         {
             [self setWaitingForDocsetInput:NO];
             cont([panel URL]);
         }
         else
         {
             NSAlert *alert = [NSAlert alertWithMessageText:@"Stash Requires Access"
                                              defaultButton:@"Okay"
                                            alternateButton:nil
                                                otherButton:@"Quit"
                                  informativeTextWithFormat:@"Stash can not function without access to Xcode's documentation.  Please select the DocSets directory."];
             NSInteger result = [alert runModal];
             switch (result)
             {
                 case NSAlertDefaultReturn:
                     [self requestAccessToDirectory:directory continuation:cont];
                     break;
                 case NSAlertOtherReturn:
                     [[NSApplication sharedApplication] stop:self];
                     break;
                 default:
                     break;
             }
         }
     }];
}

- (NSArray *)docsetRoots
{
    NSMutableArray *docsetRoots = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) mutableCopy];
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
    if ([[self preferencesController] appShouldHideWhenNotActive])
    {
        [[self window] close];
    }
}

- (IBAction)search:(id)sender
{
    NSString *searchString = [[[self searchField] stringValue] lowercaseString];
    [self hideSearchBar:self];
    [self setCurrentSearchString:searchString];
    [self setResults:[NSMutableArray array]];
    [self setSortedResults:[NSMutableArray array]];
    [[self resultsTable] reloadData];
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
                                                          [[self sortedResults] insertObject:symbol
                                                                                     atIndex:[[self sortedResults] indexOfObject:symbol
                                                                                                                   inSortedRange:NSMakeRange(0, [[self sortedResults] count])
                                                                                                                         options:NSBinarySearchingInsertionIndex
                                                                                                                 usingComparator:^ NSComparisonResult (id a, id b)
                                                                                              {
                                                                                                  return [a compare:b];
                                                                                              }]];
                                                          [[self resultsTable] insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:[[self sortedResults] indexOfObject:symbol]] withAnimation:0];
                                                          if ([[self resultsTable] selectedRow] != 0)
                                                          {
                                                              [[self resultsTable] selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                                                          }
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
    return tableView == [self indexingDocsetsView] ? [[self docsets] count] + [[self indexingDocsets] count] : [[self sortedResults] count];
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

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (tableView == [self resultsTable])
    {
        STASymbolTableViewCell *view = [[STASymbolTableViewCell alloc] initWithFrame:NSZeroRect];
        [view setSymbolName:row < [[self sortedResults] count] ? [[[self sortedResults] objectAtIndex:row] symbolName] : @""];
        [view setSymbolTypeImage:NSImageFromSTASymbolType([[[self sortedResults] objectAtIndex:row] symbolType])];
        [view setPlatformImage:NSImageFromSTAPlatform([[[[self sortedResults] objectAtIndex:row] docSet] platform])];
        return view;
    }
    else
    {
        NSArray *allDocsets = [[[self docsets] arrayByAddingObjectsFromArray:[self indexingDocsets]] sortedArrayUsingComparator:^ NSComparisonResult (STADocSet *d1, STADocSet *d2)
                               {
                                   return [[d1 name] compare:[d2 name]];
                               }];
        if ([[tableColumn identifier] isEqualToString:@"docset"])
        {
            NSTextField *textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
            [textField setEditable:NO];
            [textField setSelectable:NO];
            [textField setBordered:NO];
            [textField setDrawsBackground:NO];
            [textField setBezeled:NO];
            [[textField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
            [textField setStringValue:[[allDocsets objectAtIndex:row] name] ? : @""];
            return textField;
        }
        else if ([[tableColumn identifier] isEqualToString:@"progress"] && [[self indexingDocsets] containsObject:[allDocsets objectAtIndex:row]])
        {
            NSProgressIndicator *twirler = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0.0f, 0.0f, 16.0f, 16.0f)];
            [twirler setStyle:NSProgressIndicatorSpinningStyle];
            [twirler setControlSize:NSSmallControlSize];
            [twirler startAnimation:self];
            return twirler;
        }
        else
        {
            NSImageView *tick = [[NSImageView alloc] initWithFrame:NSZeroRect];
            [tick setImage:[NSImage imageNamed:@"Tick"]];
            return tick;
        }
    }
    return nil;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    return tableView == [self resultsTable];
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

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
    if ([control isKindOfClass:[NSSearchField class]])
    {
        [self setSelectedSearchField:(NSSearchField *)control];
    }
    return YES;
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