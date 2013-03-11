//
//  STAAppDelegate.m
//  Stash
//
//  Created by Thomas Davie on 01/06/2012.
//  Copyright (c) 2012 Thomas Davie. All rights reserved.
//

#import "STAAppDelegate.h"

#import "STADocSet.h"
#import "STADocSetStore.h"

#import "STASymbolTableViewCell.h"

@interface STAAppDelegate () <NSWindowDelegate>

@property (strong, nonatomic) STADocSetStore *docsetStore;
@property (assign,getter=isWaitingForDocsetInput) BOOL waitingForDocsetInput;

- (void)readDocsetsWithContinuation:(void(^)(void))cont;

@end

@implementation STAAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setPreferencesController:[[STAPreferencesController alloc] initWithNibNamed:@"STAPreferencesController" bundle:nil]];
    [[self preferencesController] setDelegate:self];
    [[self mainWindowController] setPreferencesController:[self preferencesController]];
    [[self mainWindowController] windowDidLoad];
    
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

    if (![[self preferencesController] appShouldHideWhenNotActive])
    {
        [self toggleStashWindow:nil];
    }
    
    unichar c = [[self preferencesController] keyboardShortcutCharacter];
    [[self openStashMenuItem] setKeyEquivalent:[NSString stringWithCharacters:&c length:1]];
    [[self openStashMenuItem] setKeyEquivalentModifierMask:[[self preferencesController] keyboardShortcutModifierFlags]];
    
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
 
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^()
                   {
                       [self readDocsetsWithContinuation:^()
                        {
                            dispatch_async(dispatch_get_main_queue(), ^()
                                           {
                                               [[self mainWindowController] setDocsetStore:[self docsetStore]];
                                           });
                        }];
                   });
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)hasVisibleWindows
{
    if (!hasVisibleWindows)
    {
        [self toggleStashWindow:nil];
    }

    return YES;
}

#define STADocumentationBookmarksKey @"DocsBookmarks"
#define STADocumentationURLsKey @"DocsURLs"

- (IBAction)addDocumentation:(id)sender
{
    [[self mainWindowController] stashWillAddDocumentation];
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
                            if (nil != bookmark)
                            {
                                NSArray *documentationBookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey:STADocumentationBookmarksKey];
                                documentationBookmarks = documentationBookmarks ? : @[];
                                documentationBookmarks = [documentationBookmarks containsObject:bookmark] ? documentationBookmarks : [documentationBookmarks arrayByAddingObject:bookmark];
                                [[NSUserDefaults standardUserDefaults] setObject:documentationBookmarks forKey:STADocumentationBookmarksKey];
                                [[NSUserDefaults standardUserDefaults] synchronize];
                            }
                            else
                            {
                                NSArray *documentationURLs = [[NSUserDefaults standardUserDefaults] arrayForKey:STADocumentationURLsKey];
                                documentationURLs = documentationURLs ? : @[];
                                NSString *urlString = [selectedRoot absoluteString];
                                documentationURLs = [documentationURLs containsObject:urlString] ? documentationURLs : [documentationURLs arrayByAddingObject:urlString];
                                [[NSUserDefaults standardUserDefaults] setObject:documentationURLs forKey:STADocumentationURLsKey];
                                [[NSUserDefaults standardUserDefaults] synchronize];
                            }
                            [self indexDocsetsWithPermissionInRoots:@[lastRoot] withContinuation:^(){}];
                        });
     }];
}

- (void)readDocsetsWithContinuation:(void(^)(void))cont
{
    [self setDocsetStore:[[STADocSetStore alloc] init]];
    
    [self readExistingIndexes];
    dispatch_async(dispatch_get_main_queue(), ^()
                   {
                       [[self mainWindowController] stashDidBeginIndexing:self];
                   });
    [self refreshExistingBookmarksWithContinuation:^()
     {
         if ([[self docsetStore] isEmpty])
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
    [[self docsetStore] setDocsets:docsets];
}

- (void)refreshExistingBookmarksWithContinuation:(void(^)(void))cont
{
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    BOOL inSandbox = (nil != [environment objectForKey:@"APP_SANDBOX_CONTAINER_ID"]);
    NSMutableArray *urls = [NSMutableArray array];
    if (inSandbox)
    {
        NSArray *documentationBookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey:STADocumentationBookmarksKey];
        for (NSData *bookmark in documentationBookmarks)
        {
            BOOL stale = NO;
            NSError *err = nil;
            NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
                                                   options:NSURLBookmarkResolutionWithSecurityScope
                                             relativeToURL:nil
                                       bookmarkDataIsStale:&stale
                                                     error:&err];
            [url startAccessingSecurityScopedResource];
            [urls addObject:url];
        }
    }
    else
    {
        NSArray *documentationURLs = [[NSUserDefaults standardUserDefaults] arrayForKey:STADocumentationURLsKey];
        for (NSString *urlString in documentationURLs)
        {
            NSURL *url = [NSURL URLWithString:urlString];
            [urls addObject:url];
        }
    }
    [self indexDocsetsWithPermissionInRoots:urls withContinuation:cont];
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
                                                   if (nil != bookmark)
                                                   {
                                                       NSArray *documentationBookmarks = [[NSUserDefaults standardUserDefaults] arrayForKey:STADocumentationBookmarksKey];
                                                       documentationBookmarks = documentationBookmarks ? : @[];
                                                       documentationBookmarks = [documentationBookmarks containsObject:bookmark] ? documentationBookmarks : [documentationBookmarks arrayByAddingObject:bookmark];
                                                       [[NSUserDefaults standardUserDefaults] setObject:documentationBookmarks forKey:STADocumentationBookmarksKey];
                                                       [[NSUserDefaults standardUserDefaults] synchronize];
                                                   }
                                                   else
                                                   {
                                                       NSArray *documentationURLs = [[NSUserDefaults standardUserDefaults] arrayForKey:STADocumentationURLsKey];
                                                       documentationURLs = documentationURLs ? : @[];
                                                       NSString *urlString = [selectedRoot absoluteString];
                                                       documentationURLs = [documentationURLs containsObject:urlString] ? documentationURLs : [documentationURLs arrayByAddingObject:urlString];
                                                       [[NSUserDefaults standardUserDefaults] setObject:documentationURLs forKey:STADocumentationURLsKey];
                                                       [[NSUserDefaults standardUserDefaults] synchronize];
                                                   }
                                                   
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
                                             [[self docsetStore] docSetDidFinishIndexing:idx];
                                             dispatch_async(dispatch_get_main_queue(), ^()
                                                            {
                                                                [[self mainWindowController] docSetsDidUpdate];
                                                            });
                                             if (finishedSearchingForDocsets && [[[self docsetStore] indexingDocsets] count] == 0)
                                             {
                                                 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), cont);
                                             }
                                         }];
                    [[self docsetStore] docSetDidBeginIndexing:docset];
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
                       [[self mainWindowController] docSetsDidUpdate];
                   });
    finishedSearchingForDocsets = YES;
    if ([[[self docsetStore] indexingDocsets] count] == 0)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), cont);
    }
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
        [NSApp activateIgnoringOtherApps:YES];
    }
}

- (void)cancelOperation:(id)sender
{
    if ([[self preferencesController] appShouldHideWhenNotActive])
    {
        [self toggleStashWindow:sender];
    }
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    if ([[self preferencesController] appShouldHideWhenNotActive])
    {
        [[self window] close];
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

#pragma mark - Prefs Delegate
- (void)preferencesControllerDidUpdateSelectedDocsets:(STAPreferencesController *)prefsController
{
    for (STADocSet *docset in [[self docsetStore] allDocsets])
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

@end
