//
//  STADocSet.m
//  Stash
//
//  Created by Thomas Davie on 01/06/2012.
//  Copyright (c) 2012 Hunted Cow Studios. All rights reserved.
//

#import "STADocSet.h"

#import "STASymbol.h"

#import "HTMLParser.h"

@interface STADocSet ()

@property (assign, getter=isLoaded) BOOL loaded;
@property (strong) NSMutableArray *symbols;

@end

@implementation STADocSet

@synthesize loaded;
@synthesize symbols;
@synthesize name;
@synthesize version;

+ (id)docSetWithURL:(NSURL *)url onceIndexed:(void(^)(STADocSet *))completion
{
    return [[self alloc] initWithURL:url onceIndexed:completion];
}

- (id)initWithURL:(NSURL *)url onceIndexed:(void(^)(STADocSet *))completion
{
    self = [super init];
    
    if (nil != self)
    {
        [self setLoaded:NO];
        NSURL *contentsDirectory = [url URLByAppendingPathComponent:@"Contents"];
        NSData *infoPlistData = [NSData dataWithContentsOfURL:[contentsDirectory URLByAppendingPathComponent:@"Info.plist"]];
        NSPropertyListFormat format;
        NSError *err = nil;
        NSDictionary *infoPlistContents = [NSPropertyListSerialization propertyListWithData:infoPlistData options:NSPropertyListImmutable format:&format error:&err];
        [self setName:[infoPlistContents objectForKey:@"CFBundleName"]];
        [self setVersion:[infoPlistContents objectForKey:@"CFBundleVersion"]];
        [self setSymbols:[NSMutableArray array]];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^()
                       {
                           @autoreleasepool
                           {
                               NSURL *resourcesURL = [contentsDirectory URLByAppendingPathComponent:@"Resources"];
                               [self processURL:resourcesURL];
                               [self setLoaded:YES];
                               dispatch_sync(dispatch_get_main_queue(), ^()
                                             {
                                                 completion(self);
                                             });
                           }
                       });
    }
    
    return self;
}

#define kDocSetSymbolsKey @"D.s"
#define kDocSetNameKey    @"D.n"
#define kDocSetVersionKey @"D.v"

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (nil != self)
    {
        [self setSymbols:[aDecoder decodeObjectForKey:kDocSetSymbolsKey]];
        [self setName:[aDecoder decodeObjectForKey:kDocSetNameKey]];
        [self setVersion:[aDecoder decodeObjectForKey:kDocSetVersionKey]];
        [self setLoaded:YES];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[self symbols] forKey:kDocSetSymbolsKey];
    [aCoder encodeObject:[self name] forKey:kDocSetNameKey];
    [aCoder encodeObject:[self version] forKey:kDocSetVersionKey];
}

- (void)processURL:(NSURL *)url
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:url includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLNameKey, NSURLIsRegularFileKey, NSURLIsDirectoryKey, nil] options:0 errorHandler:^ BOOL (NSURL *url, NSError *err)
                                         {
                                             return YES;
                                         }];
    NSURL *subUrl;
    while (subUrl = [enumerator nextObject])
    {
        @autoreleasepool
        {
            NSString *ext = [subUrl pathExtension];
            if ([ext isEqualToString:@"html"] || [ext isEqualToString:@"htm"])
            {
                NSError *parseError = nil;
                HTMLParser *parser = [[HTMLParser alloc] initWithContentsOfURL:subUrl error:&parseError];
                NSString *path = [subUrl absoluteString];

                for (HTMLNode *anchor in [[parser body] findChildTags:@"a"])
                {
                    NSString *n = [anchor getAttributeNamed:@"name"];
                    if (nil != n)
                    {
                        NSScanner *scanner = [NSScanner scannerWithString:n];
                        NSString *dump;
                        NSString *language;
                        NSString *symbolType;
                        NSString *parent;
                        NSString *symbol;
                        BOOL success = [scanner scanString:@"//apple_ref/" intoString:&dump];
                        if (!success) { continue; }
                        success = [scanner scanUpToString:@"/" intoString:&language];
                        [scanner setScanLocation:[scanner scanLocation] + 1];
                        if (!success || [language isEqualToString:@"doc"]) { continue; }
                        success = [scanner scanUpToString:@"/" intoString:&symbolType];
                        [scanner setScanLocation:[scanner scanLocation] + 1];
                        if (!success) { continue; }
                        success = [scanner scanUpToString:@"/" intoString:&parent];
                        STASymbol *s = nil;
                        NSString *fullPath = [path stringByAppendingFormat:@"#%@", n];
                        if ([scanner scanLocation] < [n length] - 1)
                        {
                            [scanner setScanLocation:[scanner scanLocation] + 1];
                            success = [scanner scanUpToString:@"/" intoString:&symbol];
                            s = [[STASymbol alloc] initWithLanguageString:language symbolTypeString:symbolType symbolName:symbol parentName:parent url:[NSURL URLWithString:fullPath]];
                        }
                        else
                        {
                            s = [[STASymbol alloc] initWithLanguageString:language symbolTypeString:symbolType symbolName:parent url:[NSURL URLWithString:fullPath]];
                        }
                        
                        STASymbolType t = [s symbolType];
                        if (t != STASymbolTypeBinding && t != STASymbolTypeTag && t != STASymbolTypeUnknown && [s language] != STALanguageUnknown)
                        {
                            [[self symbols] addObject:s];
                        }
                    }
                }
            }
        }
    }
}

- (void)search:(NSString *)searchString onResult:(void(^)(STASymbol *))result
{
    for (STASymbol *s in [self symbols])
    {
        if ([s matches:searchString])
        {
            result(s);
        }
    }
}

- (NSUInteger)hash
{
    return [[self name] hash];
}

- (BOOL)isEqual:(id)object
{
    return [[self name] isEqual:[object name]];
}

@end
