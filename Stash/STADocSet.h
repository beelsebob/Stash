//
//  STADocSet.h
//  Stash
//
//  Created by Thomas Davie on 01/06/2012.
//  Copyright (c) 2012 Hunted Cow Studios. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STASymbol.h"

typedef enum
{
    STAPlatformMacOS,
    STAPlatformIOS,
    
    STAPlatformUnknown
} STAPlatform;

@interface STADocSet : NSObject <NSCoding>

@property (copy) NSString *name;
@property (copy) NSStream *version;
@property (assign) STAPlatform platform;
@property (copy) NSString *cachePath;

+ (id)docSetWithURL:(NSURL *)url cachePath:(NSString *)cachePath onceIndexed:(void(^)(STADocSet *))completion;
- (id)initWithURL:(NSURL *)url cachePath:(NSString *)cachePath onceIndexed:(void(^)(STADocSet *))completion;

- (void)search:(NSString *)searchString onResult:(void(^)(STASymbol *))result;

- (void)unload;

@end
