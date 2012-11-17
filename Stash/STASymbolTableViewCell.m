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

@implementation STASymbolTableViewCell

@synthesize symbolTypeImage = _symbolTypeImage;
@synthesize platformImage = _platformImage;

- (id)initTextCell:(NSString *)aString
{
    self = [super initTextCell:aString];
    
    if (self != nil)
    {
        [self setFont:[NSFont fontWithName:@"Monaco" size:kFontSize]];
    }
    
    return self;
}

- (id)initImageCell:(NSImage *)image
{
    self = [super initImageCell:image];
    
    if (self != nil)
    {
        [self setFont:[NSFont fontWithName:@"Monaco" size:kFontSize]];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self != nil)
    {
        [self setFont:[NSFont fontWithName:@"Monaco" size:kFontSize]];
    }
    
    return self;
}

- (NSRect)titleRectForBounds:(NSRect)cellRect
{	
	NSSize imageSize;
	NSRect platformFrame;
    NSRect symbolTypeFrame;
    
    if (nil != [self platformImage])
    {
        imageSize = [[self platformImage] size];
        NSDivideRect(cellRect, &platformFrame, &cellRect, 3 + imageSize.width, NSMinXEdge);
        platformFrame.origin.x += kImageOriginXOffset;
        platformFrame.origin.y -= kImageOriginYOffset;
        platformFrame.size = imageSize;
        platformFrame.origin.y += ceil((cellRect.size.height - platformFrame.size.height) / 2);
    }
    if (nil != [self symbolTypeImage])
    {
        imageSize = [[self symbolTypeImage] size];
        NSDivideRect(cellRect, &symbolTypeFrame, &cellRect, 3 + imageSize.width, NSMinXEdge);
        symbolTypeFrame.origin.x += kImageOriginXOffset;
        symbolTypeFrame.origin.y -= kImageOriginYOffset;
        symbolTypeFrame.size = imageSize;
        symbolTypeFrame.origin.y += ceil((cellRect.size.height - symbolTypeFrame.size.height) / 2);
    }
	
	NSRect newFrame = cellRect;
	newFrame.origin.x += kTextOriginXOffset;
	newFrame.origin.y += kTextOriginYOffset;
	newFrame.size.height -= kTextHeightAdjust;
    
	return newFrame;
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView*)controlView editor:(NSText*)textObj delegate:(id)anObject event:(NSEvent*)theEvent
{
	NSRect textFrame = [self titleRectForBounds:aRect];
	[super editWithFrame:textFrame inView:controlView editor:textObj delegate:anObject event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
	NSRect textFrame = [self titleRectForBounds:aRect];
	[super selectWithFrame:textFrame inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	if ([self platformImage] != nil)
	{
        NSSize imageSize;
        NSRect platformFrame;
        
        imageSize = [[self platformImage] size];
        NSDivideRect(cellFrame, &platformFrame, &cellFrame, kImageOriginXOffset + imageSize.width, NSMinXEdge);
        platformFrame.origin.x += kImageOriginXOffset;
        platformFrame.origin.y += kImageOriginYOffset;
        platformFrame.size = imageSize;
		
        [[self platformImage] drawInRect:platformFrame
                                fromRect:NSMakeRect(0.0f, 0.0f, imageSize.width, imageSize.height)
                               operation:NSCompositeSourceOver
                                fraction:1.0f
                          respectFlipped:YES
                                   hints:nil];
    }
    if ([self symbolTypeImage] != nil)
    {
        NSSize imageSize;
        NSRect symbolTypeFrame;
        imageSize = [[self symbolTypeImage] size];
        NSDivideRect(cellFrame, &symbolTypeFrame, &cellFrame, kImageOriginXOffset + imageSize.width, NSMinXEdge);
        symbolTypeFrame.origin.x += kImageOriginXOffset;
        symbolTypeFrame.origin.y += kSymbolTypeImageOriginYOffset;
        symbolTypeFrame.size = imageSize;
		
        [[self symbolTypeImage] drawInRect:symbolTypeFrame
                                  fromRect:NSMakeRect(0.0f, 0.0f, imageSize.width, imageSize.height)
                                 operation:NSCompositeSourceOver
                                  fraction:1.0f
                            respectFlipped:YES
                                     hints:nil];
    }
    
    NSRect newFrame = cellFrame;
    newFrame.origin.x += kTextOriginXOffset;
    newFrame.origin.y += kTextOriginYOffset;
    newFrame.size.height -= kTextHeightAdjust;
    [super drawWithFrame:newFrame inView:controlView];
}

- (NSSize)cellSize
{
    NSSize cellSize = [super cellSize];
    cellSize.width += ([self platformImage] ? [[self platformImage] size].width : 0) + 3 + ([self symbolTypeImage] ? [[self symbolTypeImage] size].width : 0) + 3;
    return cellSize;
}

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
	return NSCellHitContentArea;
}

@end
