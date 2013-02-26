//
//  STASymbol.m
//  Stash
//
//  Created by Thomas Davie on 02/06/2012.
//  Copyright (c) 2012 Hunted Cow Studios. All rights reserved.
//

#import "STASymbol.h"

#import "STADocSet.h"

@implementation STASymbol

- (id)initWithLanguageString:(NSString *)language symbolTypeString:(NSString *)symbolType symbolName:(NSString *)symbolName url:(NSURL *)url docSet:(STADocSet *)docSet
{
    return [self initWithLanguageString:language symbolTypeString:symbolType symbolName:symbolName parentName:nil url:url docSet:docSet];
}

- (id)initWithLanguageString:(NSString *)language symbolTypeString:(NSString *)symbolType symbolName:(NSString *)symbolName parentName:(NSString *)parentName url:(NSURL *)url docSet:(STADocSet *)docSet
{
    self = [super init];
    
    if (nil != self)
    {
        [self setLanguage:STALanguageFromNSString(language)];
        [self setSymbolType:STASymbolTypeFromNSString(symbolType)];
        [self setSymbolName:symbolName];
//        [self setParentName:parentName];
        [self setUrl:url];
        [self setDocSet:docSet];
    }
    
    return self;
}

#define kSymbolLanguageKey   @"S.l"
#define kSymbolSymbolTypeKey @"S.k"
#define kSymbolSymbolNameKey @"S.n"
//#define kSymbolParentNameKey @"S.p"
#define kSymbolURLKey        @"S.u"
#define kSymbolDocSetKey     @"S.d"

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (nil != self)
    {
        [self setLanguage:[aDecoder decodeIntForKey:kSymbolLanguageKey]];
        [self setSymbolType:[aDecoder decodeIntForKey:kSymbolSymbolTypeKey]];
        [self setSymbolName:[aDecoder decodeObjectForKey:kSymbolSymbolNameKey]];
//        [self setParentName:[aDecoder decodeObjectForKey:kSymbolParentNameKey]];
        [self setUrl:[aDecoder decodeObjectForKey:kSymbolURLKey]];
        [self setDocSet:[aDecoder decodeObjectForKey:kSymbolDocSetKey]];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt:[self language] forKey:kSymbolLanguageKey];
    [aCoder encodeInt:[self symbolType] forKey:kSymbolSymbolTypeKey];
    [aCoder encodeObject:[self symbolName] forKey:kSymbolSymbolNameKey];
//    [aCoder encodeObject:[self parentName] forKey:kSymbolParentNameKey];
    [aCoder encodeObject:[self url] forKey:kSymbolURLKey];
    [aCoder encodeObject:[self docSet] forKey:kSymbolDocSetKey];
}

- (NSUInteger)hash
{
    return [_symbolName hash];
}

- (BOOL)isEqual:(id)object
{
    return _language == [(STASymbol *)object language] && _symbolType == [(STASymbol *)object symbolType] /*&& [_parentName isEqualToString:[(STASymbol *)object parentName]]*/ && [_symbolName isEqualToString:[(STASymbol *)object symbolName]];
}

- (NSString *)description
{
    switch (_language)
    {
        case STALanguageC:
        {
            switch (_symbolType)
            {
                case STASymbolTypeFunction:
                    return [NSString stringWithFormat:@"%@()", _symbolName];
                case STASymbolTypeMacro:
                    return [NSString stringWithFormat:@"#define %@", _symbolName];
                case STASymbolTypeTypeDefinition:
                    return [NSString stringWithFormat:@"typedef %@", _symbolName];
                case STASymbolTypeEnumerationConstant:
                    return [NSString stringWithFormat:@"enum { %@ }", _symbolName];
                case STASymbolTypeData:
                    return [_symbolName copy];
                default:
                    return [NSString stringWithFormat:@"C: %d (%@)", _symbolType, _symbolName];
            }
            break;
        }
        case STALanguageObjectiveC:
        {
            switch (_symbolType)
            {
                case STASymbolTypeClass:
                    return [NSString stringWithFormat:@"@interface %@", _symbolName];
                case STASymbolTypeClassMethod:
                    return [NSString stringWithFormat:@"+%@", _symbolName];
                case STASymbolTypeInstanceMethod:
                    return [NSString stringWithFormat:@"-%@", _symbolName];
                case STASymbolTypeInstanceProperty:
                    return [NSString stringWithFormat:@"@property %@", _symbolName];
                case STASymbolTypeInterfaceClassMethod:
                    return [NSString stringWithFormat:@"+%@", _symbolName];
                case STASymbolTypeInterfaceMethod:
                    return [NSString stringWithFormat:@"-%@", _symbolName];
                case STASymbolTypeInterfaceProperty:
                    return [NSString stringWithFormat:@"@property %@", _symbolName];
                case STASymbolTypeCategory:
                    return [NSString stringWithFormat:@"@interface ?(%@)", _symbolName];
                case STASymbolTypeInterface:
                    return [NSString stringWithFormat:@"@protocol %@", _symbolName];
                default:
                    return [NSString stringWithFormat:@"Obj-C: %d (%@)", _symbolType, _symbolName];
            }
        }
        default:
            return @"";
    }
}

- (BOOL)matches:(NSString *)searchString method:(STASearchMethod)method
{
    switch (method)
    {
        case STASearchMethodPrefix:
            return [[_symbolName lowercaseString] hasPrefix:searchString];
        case STASearchMethodContains:
            return [[_symbolName lowercaseString] rangeOfString:searchString].location != NSNotFound;
    }
}

- (NSComparisonResult)compare:(id)other
{
    NSComparisonResult r = [_symbolName compare:[other symbolName]];
    if (r == NSOrderedSame)
    {
        STAPlatform p1 = [_docSet platform];
        STAPlatform p2 = [[other docSet] platform];
        return p1 < p2 ? NSOrderedAscending : p1 > p2 ? NSOrderedDescending : NSOrderedSame;
    }
    return r;
}

@end

STALanguage STALanguageFromNSString(NSString *languageString)
{
    static NSDictionary *languageStrings = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        languageStrings = (@{
                           @"c"          : @(STALanguageC),
                           @"occ"        : @(STALanguageObjectiveC),
                           @"cpp"        : @(STALanguageCPlusPlus),
                           @"javascript" : @(STALanguageJavascript)
                           });
    });
    
    NSNumber *language = languageStrings[languageString];
    return language == nil ? STALanguageUnknown : [language intValue];
}

STASymbolType STASymbolTypeFromNSString(NSString *symbolTypeString)
{
    static NSDictionary *symbolTypeStrings = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        symbolTypeStrings = (@{
                             @"func"    : @(STASymbolTypeFunction),
                             @"macro"   : @(STASymbolTypeMacro),
                             @"instm"   : @(STASymbolTypeInstanceMethod),
                             @"econst"  : @(STASymbolTypeEnumerationConstant),
                             @"data"    : @(STASymbolTypeData),
                             @"instp"   : @(STASymbolTypeInstanceProperty),
                             @"intfp"   : @(STASymbolTypeInterfaceProperty),
                             @"intfm"   : @(STASymbolTypeInterfaceMethod),
                             @"intfcm"  : @(STASymbolTypeInterfaceClassMethod),
                             @"tag"     : @(STASymbolTypeTag),
                             @"clm"     : @(STASymbolTypeClassMethod),
                             @"tdef"    : @(STASymbolTypeTypeDefinition),
                             @"cl"      : @(STASymbolTypeClass),
                             @"intf"    : @(STASymbolTypeInterface),
                             @"cat"     : @(STASymbolTypeCategory),
                             @"binding" : @(STASymbolTypeBinding),
                             @"clconst" : @(STASymbolTypeClassConstant)
                             });
    });
    
    NSNumber *symbolType = symbolTypeStrings[symbolTypeString];
    return symbolType == nil ? STASymbolTypeUnknown : [symbolType intValue];
}
