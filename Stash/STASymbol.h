//
//  STASymbol.h
//  Stash
//
//  Created by Thomas Davie on 02/06/2012.
//  Copyright (c) 2012 Hunted Cow Studios. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : unsigned char
{
    STALanguageC,
    STALanguageCPlusPlus,
    STALanguageObjectiveC,
    STALanguageJavascript,
    
    STALanguageUnknown
} STALanguage;

typedef enum : unsigned char
{
    STASymbolTypeFunction,
    STASymbolTypeMacro,
    STASymbolTypeTypeDefinition,
    STASymbolTypeClass,
    STASymbolTypeInterface,
    STASymbolTypeCategory,
    STASymbolTypeClassMethod,
    STASymbolTypeClassConstant,
    STASymbolTypeInstanceMethod,
    STASymbolTypeInstanceProperty,
    STASymbolTypeInterfaceMethod,
    STASymbolTypeInterfaceClassMethod,
    STASymbolTypeInterfaceProperty,
    STASymbolTypeEnumerationConstant,
    STASymbolTypeData,
    STASymbolTypeTag,
    STASymbolTypeBinding,
    
    STASymbolTypeUnknown
} STASymbolType;

STALanguage STALanguageFromNSString(NSString *languageString);
STASymbolType STASymbolTypeFromNSString(NSString *symbolTypeString);

@interface STASymbol : NSObject <NSCoding>

@property (assign) STALanguage language;
@property (assign) STASymbolType symbolType;
@property (copy) NSString *symbolName;
@property (copy) NSString *parentName;
@property (copy) NSURL *url;

- (id)initWithLanguageString:(NSString *)language symbolTypeString:(NSString *)symbolType symbolName:(NSString *)symbolName url:(NSURL *)url;
- (id)initWithLanguageString:(NSString *)language symbolTypeString:(NSString *)symbolType symbolName:(NSString *)symbolName parentName:(NSString *)parentName url:(NSURL *)url;

- (BOOL)matches:(NSString *)searchString;

@end
