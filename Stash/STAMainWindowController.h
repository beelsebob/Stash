//
//  STAMainWindowController.h
//  Stash
//
//  Created by Tom Davie on 03/03/2013.
//
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "STADocSetStore.h"

#import "STAPreferencesController.h"

@interface STAMainWindowController : NSWindowController <NSWindowDelegate>

@property (strong, nonatomic) STADocSetStore *docsetStore;

@property (strong) IBOutlet NSTableView *resultsTable;
@property (strong) IBOutlet WebView *resultWebView;
@property (strong) IBOutlet NSTextField *titleView;
@property (strong) IBOutlet NSSearchField *searchField;
@property (weak) IBOutlet NSMatrix *searchMethodSelector;
@property (weak) IBOutlet NSSearchField *inPageSearchField;
@property (weak) IBOutlet NSTableView *indexingDocsetsView;
@property (weak) IBOutlet NSScrollView *indexingDocsetsContainer;
@property (weak) IBOutlet NSView *docsetsNotFoundView;
@property (weak) IBOutlet NSLayoutConstraint *findBarHeightConstraint;

@property (strong) STAPreferencesController *preferencesController;

- (IBAction)search:(id)sender;
- (IBAction)setSearchMethod:(id)sender;
- (IBAction)hideSearchBar:(id)sender;
- (IBAction)showFindUI;
- (IBAction)searchWithinPage:(id)sender;

- (void)stashDidBeginIndexing:(id)sender;
- (void)stashWillAddDocumentation;
- (void)docSetsDidUpdate;

@end
