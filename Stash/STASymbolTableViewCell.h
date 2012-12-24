//
//  STASymbolTableViewCell.h
//  Stash
//
//  Created by Thomas Davie on 03/06/2012.
//  Copyright (c) 2012 Hunted Cow Studios. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface STASymbolTableViewCell : NSView

@property (strong,nonatomic) NSImage *symbolTypeImage;
@property (strong,nonatomic) NSImage *platformImage;
@property (copy  ,nonatomic) NSString *symbolName;

@end
