//
//  STASymbol.m
//  Stash
//
//  Created by Thomas Davie on 02/06/2012.
//  Copyright (c) 2012 Hunted Cow Studios. All rights reserved.
//

#import "STASymbol.h"

@implementation STASymbol

@synthesize language = _language;
@synthesize symbolType = _symbolType;
@synthesize symbolName = _symbolName;
@synthesize parentName = _parentName;
@synthesize url = _url;

- (id)initWithLanguageString:(NSString *)language symbolTypeString:(NSString *)symbolType symbolName:(NSString *)symbolName url:(NSURL *)url
{
    return [self initWithLanguageString:language symbolTypeString:symbolType symbolName:symbolName parentName:nil url:url];
}

- (id)initWithLanguageString:(NSString *)language symbolTypeString:(NSString *)symbolType symbolName:(NSString *)symbolName parentName:(NSString *)parentName url:(NSURL *)url
{
    self = [super init];
    
    if (nil != self)
    {
        [self setLanguage:STALanguageFromNSString(language)];
        [self setSymbolType:STASymbolTypeFromNSString(symbolType)];
        [self setSymbolName:symbolName];
        [self setParentName:parentName];
        [self setUrl:url];
    }
    
    return self;
}

#define kSymbolLanguageKey   @"S.l"
#define kSymbolSymbolTypeKey @"S.k"
#define kSymbolSymbolNameKey @"S.n"
#define kSymbolParentNameKey @"S.p"
#define kSymbolURLKey        @"S.u"

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (nil != self)
    {
        [self setLanguage:[aDecoder decodeIntForKey:kSymbolLanguageKey]];
        [self setSymbolType:[aDecoder decodeIntForKey:kSymbolSymbolTypeKey]];
        [self setSymbolName:[aDecoder decodeObjectForKey:kSymbolSymbolNameKey]];
        [self setParentName:[aDecoder decodeObjectForKey:kSymbolParentNameKey]];
        [self setUrl:[aDecoder decodeObjectForKey:kSymbolURLKey]];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt:[self language] forKey:kSymbolLanguageKey];
    [aCoder encodeInt:[self symbolType] forKey:kSymbolSymbolTypeKey];
    [aCoder encodeObject:[self symbolName] forKey:kSymbolSymbolNameKey];
    [aCoder encodeObject:[self parentName] forKey:kSymbolParentNameKey];
    [aCoder encodeObject:[self url] forKey:kSymbolURLKey];
}

- (NSUInteger)hash
{
    return [_symbolName hash];
}

- (BOOL)isEqual:(id)object
{
    return _language == [(STASymbol *)object language] && _symbolType == [(STASymbol *)object symbolType] && [_parentName isEqualToString:[(STASymbol *)object parentName]] && [_symbolName isEqualToString:[(STASymbol *)object parentName]];
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
                default:
                    return [NSString stringWithFormat:@"C: %d", _symbolType];
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
                    return [NSString stringWithFormat:@"+[%@ %@]", _parentName, _symbolName];
                case STASymbolTypeInstanceMethod:
                    return [NSString stringWithFormat:@"-[%@ %@]", _parentName, _symbolName];
                case STASymbolTypeInstanceProperty:
                    return [NSString stringWithFormat:@"@property %@", _symbolName];
                case STASymbolTypeCategory:
                    return [NSString stringWithFormat:@"@interface %@", _symbolName];
                default:
                    return [NSString stringWithFormat:@"Obj-C: %d", _symbolType];
            }
        }
        default:
            return @"";
    }
}

- (BOOL)matches:(NSString *)searchString
{
    return [[_symbolName lowercaseString] hasPrefix:searchString];
}

- (NSComparisonResult)compare:(id)other
{
    return [_symbolName compare:[other symbolName]];
}

@end

STALanguage STALanguageFromNSString(NSString *languageString)
{
    if ([languageString isEqualToString:@"c"])
    {
        return STALanguageC;
    }
    else if ([languageString isEqualToString:@"occ"])
    {
        return STALanguageObjectiveC;
    }
    else if ([languageString isEqualToString:@"cpp"])
    {
        return STALanguageCPlusPlus;
    }
    else if ([languageString isEqualToString:@"javascript"])
    {
        return STALanguageJavascript;
    }
    return STALanguageUnknown;
}

STASymbolType STASymbolTypeFromNSString(NSString *symbolTypeString)
{
    if ([symbolTypeString isEqualToString:@"func"])
    {
        return STASymbolTypeFunction;
    }
    else if ([symbolTypeString isEqualToString:@"macro"])
    {
        return STASymbolTypeMacro;
    }
    else if ([symbolTypeString isEqualToString:@"instm"])
    {
        return STASymbolTypeInstanceMethod;
    }
    else if ([symbolTypeString isEqualToString:@"econst"])
    {
        return STASymbolTypeEnumerationConstant;
    }
    else if ([symbolTypeString isEqualToString:@"data"])
    {
        return STASymbolTypeData;
    }
    else if ([symbolTypeString isEqualToString:@"instp"])
    {
        return STASymbolTypeInstanceProperty;
    }
    else if ([symbolTypeString isEqualToString:@"intfp"])
    {
        return STASymbolTypeInterfaceProperty;
    }
    else if ([symbolTypeString isEqualToString:@"intfm"])
    {
        return STASymbolTypeInterfaceMethod;
    }
    else if ([symbolTypeString isEqualToString:@"intfcm"])
    {
        return STASymbolTypeInterfaceClassMethod;
    }
    else if ([symbolTypeString isEqualToString:@"tag"])
    {
        return STASymbolTypeTag;
    }
    else if ([symbolTypeString isEqualToString:@"clm"])
    {
        return STASymbolTypeClassMethod;
    }
    else if ([symbolTypeString isEqualToString:@"tdef"])
    {
        return STASymbolTypeTypeDefinition;
    }
    else if ([symbolTypeString isEqualToString:@"cl"])
    {
        return STASymbolTypeClass;
    }
    else if ([symbolTypeString isEqualToString:@"intf"])
    {
        return STASymbolTypeInterface;
    }
    else if ([symbolTypeString isEqualToString:@"cat"])
    {
        return STASymbolTypeCategory;
    }
    else if ([symbolTypeString isEqualToString:@"binding"])
    {
        return STASymbolTypeBinding;
    }
    else if ([symbolTypeString isEqualToString:@"clconst"])
    {
        return STASymbolTypeClassConstant;
    }
    
    return STASymbolTypeUnknown;
}
