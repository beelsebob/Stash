//
//  STADocSetStore.h
//  Stash
//
//  Created by Tom Davie on 11/03/2013.
//
//

#import <Foundation/Foundation.h>

#import "STADocSet.h"

@interface STADocSetStore : NSObject

@property (copy, nonatomic) NSArray *docsets;
@property (copy, nonatomic) NSArray *indexingDocsets;

@property (readonly, nonatomic) NSArray *allDocsets;

@property (readonly) BOOL isEmpty;

- (void)docSetDidBeginIndexing:(STADocSet *)docset;
- (void)docSetDidFinishIndexing:(STADocSet *)docset;

@end
