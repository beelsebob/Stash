//
//  STAMainWindowController.m
//  Stash
//
//  Created by Tom Davie on 03/03/2013.
//
//

#import "STAMainWindowController.h"

#import "STADocSet.h"

#import "STASymbolTableViewCell.h"

NSImage *NSImageFromSTASymbolType(STASymbolType t);
NSImage *NSImageFromSTAPlatform(STAPlatform p);

@interface STAMainWindowController ()

@property (copy) NSString *currentSearchString;
@property (strong) NSMutableArray *results;
@property (strong) NSMutableArray *sortedResults;
@property (assign, getter=isFindUIShowing) BOOL findUIShowing;
@property (weak) NSSearchField *selectedSearchField;

- (void)showFindUI;
- (void)searchAgain:(BOOL)backwards;

@end

@implementation STAMainWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    NSRect findBarRect = [[self findBar] frame];
    findBarRect.origin.y += findBarRect.size.height;
    findBarRect.size.height = 0.0f;
    [[self findBar] setFrame:findBarRect];
    NSRect resultWebViewFrame = [[self resultWebView] frame];
    resultWebViewFrame.size.height = findBarRect.origin.y - resultWebViewFrame.origin.y;
    [[self resultWebView] setFrame:resultWebViewFrame];
    
    [[[self resultWebView] preferences] setJavaEnabled:NO];
    [[[self resultWebView] preferences] setJavaScriptEnabled:NO];
    [[[self resultWebView] preferences] setJavaScriptCanOpenWindowsAutomatically:NO];
    [[[self resultWebView] preferences] setPlugInsEnabled:NO];
    
    [[self searchField] setEnabled:NO];
    [[self titleView] setStringValue:@"Stash is Loading, Please Wait..."];
    
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
}

- (void)setDocsetStore:(STADocSetStore *)docsetStore
{
    _docsetStore = docsetStore;
    
    [[self searchField] setEnabled:YES];
    [[self searchField] selectText:self];
    [[self indexingDocsetsContainer] setHidden:YES];
    if ([[[self docsetStore] allDocsets] count] > 0)
    {
        [[self titleView] setStringValue:@""];
    }
    else
    {
        [[self titleView] setStringValue:@"Stash Could Not Find Any Documentation"];
        [[self docsetsNotFoundView] setHidden:NO];
    }
}

- (void)showFindUI
{
    [[self window] makeFirstResponder:[self inPageSearchField]];
    if (![self isFindUIShowing])
    {
        [self setFindUIShowing:YES];
        CGRect findBarFrame = [[self findBar] frame];
        findBarFrame.origin.y -= 25.0f;
        findBarFrame.size.height = 25.0f;
        NSRect resultWebViewFrame = [[self resultWebView] frame];
        resultWebViewFrame.size.height = findBarFrame.origin.y - resultWebViewFrame.origin.y;
        [NSAnimationContext runAnimationGroup:^ (NSAnimationContext *ctx)
         {
             [ctx setDuration:0.15];
             [[[self findBar] animator] setFrame:findBarFrame];
             [[[self resultWebView] animator] setFrame:resultWebViewFrame];
         }
                            completionHandler:^(){}];
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
        CGRect findBarFrame = [[self findBar] frame];
        findBarFrame.origin.y += findBarFrame.size.height;
        findBarFrame.size.height = 0.0f;
        NSRect resultWebViewFrame = [[self resultWebView] frame];
        resultWebViewFrame.size.height = findBarFrame.origin.y - resultWebViewFrame.origin.y;
        [NSAnimationContext runAnimationGroup:^ (NSAnimationContext *ctx)
         {
             [ctx setDuration:0.15];
             [[[self findBar] animator] setFrame:findBarFrame];
             [[[self resultWebView] animator] setFrame:resultWebViewFrame];
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
                           [self searchDocSet:docSet forString:searchString];
                       });
    }
}

- (void)searchDocSet:(STADocSet *)docSet forString:(NSString *)searchString
{
    @autoreleasepool
    {
        [docSet search:searchString
                method:[[self searchMethodSelector] selectedRow] == 0 ? STASearchMethodPrefix : STASearchMethodContains
              onResult:^(STASymbol *symbol)
         {
             [self setResultNeedsDisplay:symbol forSearchString:searchString];
         }];
    }
}

- (void)setResultNeedsDisplay:(STASymbol *)symbol forSearchString:(NSString *)searchString
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
}

- (IBAction)setSearchMethod:(id)sender
{
    [self search:sender];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    [[self window] makeFirstResponder:[self searchField]];
    [[self searchField] selectText:self];
}

- (void)stashDidBeginIndexing:(id)sender
{
    [[self titleView] setStringValue:@"Stash is Indexing, Please Wait..."];
    [[self indexingDocsetsContainer] setHidden:NO];
    [[self indexingDocsetsView] reloadData];
}

- (void)stashWillAddDocumentation
{
    [[self docsetsNotFoundView] setHidden:YES];
}

- (void)docSetsDidUpdate
{
    [[self indexingDocsetsView] reloadData];
}

#pragma mark - Table View Data Source
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return tableView == [self indexingDocsetsView] ? [[[self docsetStore] allDocsets] count] : [[self sortedResults] count];
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
        NSArray *allDocsets = [[[self docsetStore] allDocsets] sortedArrayUsingComparator:^ NSComparisonResult (STADocSet *d1, STADocSet *d2)
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
        else if ([[tableColumn identifier] isEqualToString:@"progress"] && [[[self docsetStore] indexingDocsets] containsObject:[allDocsets objectAtIndex:row]])
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

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    if (dividerIndex == 0)
    {
        return 229.0f;
    }
    return proposedMinimumPosition;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view
{
    return view != [self searchColumn];
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
