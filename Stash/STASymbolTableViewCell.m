//
//  STASymbolTableViewCell.m
//  Stash
//
//  Created by Thomas Davie on 03/06/2012.
//  Copyright (c) 2012 Hunted Cow Studios. All rights reserved.
//

#import "STASymbolTableViewCell.h"

#define kIconImageSize		128.0

#define kFontSize           12.0

#define kImageOriginXOffset           3
#define kImageOriginYOffset           1
#define kSymbolTypeImageOriginYOffset 3

#define kTextOriginXOffset	2
#define kTextOriginYOffset	2
#define kTextHeightAdjust	4

@interface STASymbolTableViewCell ()

@property (readwrite,strong,nonatomic) NSImageView *platformView;
@property (readwrite,strong,nonatomic) NSImageView *symbolTypeView;
@property (readwrite,strong,nonatomic) NSTextField *textField;

@end

@implementation STASymbolTableViewCell

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    
    if (self != nil)
    {
        [self commonInit];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self != nil)
    {
        [self commonInit];
    }
    
    return self;
}

- (void)commonInit
{
    NSRect platformRect = NSMakeRect(3.0f, 0.0f, 16.0f, [self bounds].size.height);
    NSRect symbolTypeRect = NSMakeRect(22.0f, 0.0f, 16.0f, [self bounds].size.height);
    NSRect textRect = NSMakeRect(41.0f, 0.0f, [self bounds].size.width - 41.0f, [self bounds].size.height - 3.0f);
    [self setPlatformView:[[NSImageView alloc] initWithFrame:platformRect]];
    [[self platformView] setImage:[self platformImage]];
    [self addSubview:[self platformView]];
    [self setSymbolTypeView:[[NSImageView alloc] initWithFrame:symbolTypeRect]];
    [[self symbolTypeView] setImage:[self symbolTypeImage]];
    [self addSubview:[self symbolTypeView]];
    [self setTextField:[[NSTextField alloc] initWithFrame:textRect]];
    [[self textField] setFont:[NSFont fontWithName:@"Monaco" size:kFontSize]];
    [[self textField] setEditable:NO];
    [[self textField] setSelectable:NO];
    [[self textField] setBordered:NO];
    [[self textField] setDrawsBackground:NO];
    [[self textField] setBezeled:NO];
    [[[self textField] cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [[self textField] setStringValue:[self symbolName] ? : @""];
    [self addSubview:[self textField]];
}

- (void)setFrame:(NSRect)aRect
{
    [super setFrame:aRect];
    NSRect platformRect = NSMakeRect(3.0f, 0.0f, 16.0f, [self bounds].size.height);
    NSRect symbolTypeRect = NSMakeRect(22.0f, 0.0f, 16.0f, [self bounds].size.height);
    NSRect textRect = NSMakeRect(41.0f, 0.0f, [self bounds].size.width - 41.0f, [self bounds].size.height - 3.0f);
    [[self platformView] setFrame:platformRect];
    [[self symbolTypeView] setFrame:symbolTypeRect];
    [[self textField] setFrame:textRect];
}

- (void)setPlatformImage:(NSImage *)platformImage
{
    if (platformImage != _platformImage)
    {
        _platformImage = platformImage;
        [[self platformView] setImage:platformImage];
    }
}

- (void)setSymbolTypeImage:(NSImage *)symbolTypeImage
{
    if (symbolTypeImage != _symbolTypeImage)
    {
        _symbolTypeImage = symbolTypeImage;
        [[self symbolTypeView] setImage:symbolTypeImage];
    }
}

- (void)setSymbolName:(NSString *)symbolName
{
    if (symbolName != _symbolName)
    {
        _symbolName = [symbolName copy];
        [[self textField] setStringValue:_symbolName ? : @""];
    }
}

@end
