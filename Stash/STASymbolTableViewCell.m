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

#define kImageOriginXOffset 3
#define kImageOriginYOffset 1

#define kTextOriginXOffset	2
#define kTextOriginYOffset	2
#define kTextHeightAdjust	4

@implementation STASymbolTableViewCell

@synthesize image = _image;

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
	NSRect imageFrame;
    
	imageSize = [[self image] size];
	NSDivideRect(cellRect, &imageFrame, &cellRect, 3 + imageSize.width, NSMinXEdge);
    
	imageFrame.origin.x += kImageOriginXOffset;
	imageFrame.origin.y -= kImageOriginYOffset;
	imageFrame.size = imageSize;
	
	imageFrame.origin.y += ceil((cellRect.size.height - imageFrame.size.height) / 2);
	
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
	if ([self image] != nil)
	{
		NSSize imageSize = [[self image] size];
        NSRect imageFrame;
        
        NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
        
        imageFrame.origin.x += kImageOriginXOffset;
		imageFrame.origin.y -= kImageOriginYOffset;
        imageFrame.size = imageSize;
		
        imageFrame.origin.y += ceil(([controlView isFlipped] ? cellFrame.size.height + imageFrame.size.height : cellFrame.size.height - imageFrame.size.height) / 2);
		[[self image] compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
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
    cellSize.width += ([self image] ? [[self image] size].width : 0) + 3;
    return cellSize;
}

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
	return NSCellHitContentArea;
}

@end
