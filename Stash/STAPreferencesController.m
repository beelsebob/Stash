//
//  STAPreferencesController.m
//  Stash
//
//  Created by Thomas Davie on 04/06/2012.
//  Copyright (c) 2012 Hunted Cow Studios. All rights reserved.
//

#import "STAPreferencesController.h"

#import "STAAppDelegate.h"

#define kModifierFlagsKey @"Modifier Flags"
#define kKeyboardShortcutKey @"Keyboard Shortcut"
#define kHidesWhenNotActiveKey @"Hides When Not Active"
#define kShowsIconWhereKey @"Shows Icon Where"
#define kEnabledDocsetsKey @"Enabled Docsets"

NSString *descriptionStringFromChar(unichar c);

NSString *descriptionStringFromChar(unichar c)
{
    switch (c)
    {
        case ' ':
            return @"Space";
        case NSBackspaceCharacter:
        {
            unichar d = 0x232b;
            return [NSString stringWithCharacters:&d length:1];
        }
        case NSDeleteCharacter:
        {
            unichar d = 0x2326;
            return [NSString stringWithCharacters:&d length:1];
        }
        case '\n':
        {
            unichar d = 0x23ce;
            return [NSString stringWithCharacters:&d length:1];
        }
        case 0x1b:
        {
            unichar d = 0x238b;
            return [NSString stringWithCharacters:&d length:1];
        }
        case 0x9:
        {
            unichar d = 0x21e5;
            return [NSString stringWithCharacters:&d length:1];
        }
        default:
            return [[NSString stringWithCharacters:&c length:1] uppercaseString];
    }
}

@interface STAPreferencesController ()

@property (strong) NSMutableArray *internalRegisteredDocsets;
@property (weak) id eventMonitor;

- (NSDictionary *)defaultPreferences;
- (NSArray *)registeredDocsets;

@end

@implementation STAPreferencesController

- (id)initWithNibNamed:(NSString *)nibName bundle:(NSBundle *)bundle
{
    self = [super init];
    
    if (nil != self)
    {
        NSArray *topLevelObjects = nil;
        BOOL success = [[[NSNib alloc] initWithNibNamed:nibName bundle:bundle] instantiateNibWithOwner:self topLevelObjects:&topLevelObjects];
        if (!success)
        {
            return nil;
        }
        [self setEventMonitor:nil];
        [self setInternalRegisteredDocsets:[NSMutableArray array]];
        [[NSUserDefaults standardUserDefaults] registerDefaults:[self defaultPreferences]];
    }
    
    return self;
}

- (void)showWindow
{
    [self setupShortcutText];
    
    [[self hideWhenNotActiveCheckbox] setState:[[NSUserDefaults standardUserDefaults] boolForKey:kHidesWhenNotActiveKey]];
    [[self showIconMenuButton] selectItemAtIndex:[[NSUserDefaults standardUserDefaults] integerForKey:kShowsIconWhereKey]];
    
    [[self window] makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)setupShortcutText
{
    NSMutableString *keyboardShortcutString = [NSMutableString stringWithString:@""];
    NSUInteger modifierFlags = [self keyboardShortcutModifierFlags];
    unichar command = 0x2318;
    unichar alt     = 0x2325;
    unichar ctrl    = 0x2303;
    unichar shift   = 0x21E7;
    if (modifierFlags & NSControlKeyMask)
    {
        [keyboardShortcutString appendString:[NSString stringWithCharacters:&ctrl length:1]];
    }
    if (modifierFlags & NSAlternateKeyMask)
    {
        [keyboardShortcutString appendString:[NSString stringWithCharacters:&alt length:1]];
    }
    if (modifierFlags & NSShiftKeyMask)
    {
        [keyboardShortcutString appendString:[NSString stringWithCharacters:&shift length:1]];
    }
    if (modifierFlags & NSCommandKeyMask)
    {
        [keyboardShortcutString appendString:[NSString stringWithCharacters:&command length:1]];
    }
    [keyboardShortcutString appendString:descriptionStringFromChar([self keyboardShortcutCharacter])];
    [[self shortcutText] setStringValue:keyboardShortcutString];
}

- (NSDictionary *)defaultPreferences
{
    NSArray *docsets = [self registeredDocsets];
    NSMutableArray *registeredDocsetNames = [NSMutableArray arrayWithCapacity:[docsets count]];
    for (STADocSet *docset in docsets)
    {
        [registeredDocsetNames addObject:[docset name]];
    }
    
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedInteger:NSCommandKeyMask | NSControlKeyMask], kModifierFlagsKey,
            [NSNumber numberWithInt:' '], kKeyboardShortcutKey,
            [NSNumber numberWithBool:YES], kHidesWhenNotActiveKey,
            [NSNumber numberWithInt:STAIconShowingModeMenuBar], kShowsIconWhereKey,
            registeredDocsetNames, kEnabledDocsetsKey,
            nil];
}

- (void)registerDocset:(STADocSet *)docset
{
    [[self internalRegisteredDocsets] addObject:docset];
    [[self docsetTable] reloadData];
    [[NSUserDefaults standardUserDefaults] registerDefaults:[self defaultPreferences]];
}

- (IBAction)changeShortcut:(id)sender
{
    [NSEvent removeMonitor:[self eventMonitor]];
    [self setEventMonitor:[NSEvent addLocalMonitorForEventsMatchingMask:NSKeyUpMask handler:^ NSEvent * (NSEvent *e)
                           {
                               [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInteger:[e modifierFlags] & NSDeviceIndependentModifierFlagsMask]
                                                                         forKey:kModifierFlagsKey];
                               [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:[[e charactersIgnoringModifiers] characterAtIndex:0]]
                                                                         forKey:kKeyboardShortcutKey];
                               [self setupShortcutText];
                               [[self shortcutButton] setState:NSOffState];
                               [self performSelector:@selector(removeEventMonitor) withObject:nil afterDelay:0.0];
                               [[self delegate] preferencesControllerDidUpdateMenuShortcut:self];
                               return e;
                           }]];
}

- (IBAction)showIconChanged:(id)sender
{
    NSInteger selection = [[self showIconMenuButton] indexOfSelectedItem];
    NSInteger oldSelection = [[NSUserDefaults standardUserDefaults] integerForKey:kShowsIconWhereKey];
    [[NSUserDefaults standardUserDefaults] setInteger:selection
                                               forKey:kShowsIconWhereKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (selection == STAIconShowingModeBoth || selection == STAIconShowingModeDock)
    {
        [[NSApplication sharedApplication] setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
    else
    {
        [[NSApplication sharedApplication] setActivationPolicy:NSApplicationActivationPolicyAccessory];
        if (oldSelection != selection)
        {
            NSAlert *alert = [NSAlert alertWithMessageText:@"Restart Required"
                                             defaultButton:@"Okay"
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:@"In order to remove Stash from the dock, you must restart it."];
            [alert runModal];
        }
    }
    
    STAAppDelegate *del = (STAAppDelegate *)[[NSApplication sharedApplication] delegate];
    if (selection == STAIconShowingModeMenuBar || selection == STAIconShowingModeBoth)
    {
        [del setStatusItem:[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength]];
        [[del statusItem] setMenu:[del statusMenu]];
        [[del statusItem] setTitle:@"Stash"];
        [[del statusItem] setHighlightMode:YES];
    }
    else
    {
        [del setStatusItem:nil];
    }
}

- (IBAction)hideWhenNotActiveChanged:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[[self hideWhenNotActiveCheckbox] state] == NSOnState]
                                              forKey:kHidesWhenNotActiveKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)removeEventMonitor
{
    [NSEvent removeMonitor:[self eventMonitor]];
    [self setEventMonitor:nil];
}

- (BOOL)isMonitoringForEvents
{
    return [self eventMonitor] != nil;
}

- (BOOL)appShouldHideWhenNotActive
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:kHidesWhenNotActiveKey];
}

- (STAIconShowingMode)iconMode
{
    return (STAIconShowingMode)[[NSUserDefaults standardUserDefaults] integerForKey:kShowsIconWhereKey];
}

- (NSArray *)registeredDocsets
{
    return [[self internalRegisteredDocsets] copy];
}

- (NSArray *)enabledDocsets
{
    NSArray *enabledDocsetNames = [[NSUserDefaults standardUserDefaults] objectForKey:kEnabledDocsetsKey];
    NSMutableArray *enabledDocsets = [NSMutableArray arrayWithCapacity:[enabledDocsetNames count]];
    for (STADocSet *docset in [self registeredDocsets])
    {
        if ([enabledDocsetNames containsObject:[docset name]])
        {
            [enabledDocsets addObject:docset];
        }
    }
    return [enabledDocsets copy];
}

- (unichar)keyboardShortcutCharacter
{
    return (unichar) [[[NSUserDefaults standardUserDefaults] objectForKey:kKeyboardShortcutKey] intValue];
}

- (NSUInteger)keyboardShortcutModifierFlags
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:kModifierFlagsKey] unsignedIntegerValue];
}

#pragma mark - Table View Data Source
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [[self registeredDocsets] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (row < 0)
    {
        return nil;
    }

    STADocSet *docSet = [[[self registeredDocsets] sortedArrayUsingComparator:^ NSComparisonResult (STADocSet *ds1, STADocSet *ds2)
    {
        return [[ds1 name] compare:[ds2 name]];
    }] objectAtIndex:(NSUInteger) row];

    if ([[tableColumn identifier] isEqualToString:@"name"])
    {
        return [docSet name];
    }
    else
    {
        return [NSNumber numberWithBool:[[self enabledDocsets] containsObject:docSet]];
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (row < 0)
    {
        return;
    }

    STADocSet *docSet = [[[self registeredDocsets] sortedArrayUsingComparator:^NSComparisonResult(STADocSet *ds1, STADocSet *ds2)
    {
        return [[ds1 name] compare:[ds2 name]];
    }] objectAtIndex:(NSUInteger) row];

    if (![[tableColumn identifier] isEqualToString:@"name"])
    {
        NSMutableArray *enabledDocsetNames = [[[NSUserDefaults standardUserDefaults] objectForKey:kEnabledDocsetsKey] mutableCopy];
        if ([object boolValue])
        {
            [enabledDocsetNames addObject:[docSet name]];
        }
        else
        {
            [enabledDocsetNames removeObject:[docSet name]];
        }
        [[NSUserDefaults standardUserDefaults] setObject:enabledDocsetNames forKey:kEnabledDocsetsKey];
        [[self delegate] preferencesControllerDidUpdateSelectedDocsets:self];
    }
}

@end
