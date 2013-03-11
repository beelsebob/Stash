//
//  STADocSetStore.m
//  Stash
//
//  Created by Tom Davie on 11/03/2013.
//
//

#import "STADocSetStore.h"

@implementation STADocSetStore
{
    NSMutableArray *_indexingDocsets;
    NSMutableArray *_docsets;
    dispatch_queue_t _docsetArrayEditingQueue;
}

- (NSArray *)indexingDocsets
{
    return [_indexingDocsets copy];
}

- (void)setIndexingDocsets:(NSArray *)indexingDocsets
{
    if (indexingDocsets != _indexingDocsets)
    {
        _indexingDocsets = [indexingDocsets mutableCopy];
    }
}

- (NSArray *)docsets
{
    return [_docsets copy];
}

- (void)setDocsets:(NSArray *)docsets
{
    if (docsets != _docsets)
    {
        _docsets = [docsets mutableCopy];
    }
}

- (instancetype)init
{
    self = [super init];
    
    if (nil != self)
    {
        _docsetArrayEditingQueue = dispatch_queue_create("org.beelsebob.Stash.docsetArrayEditing", DISPATCH_QUEUE_SERIAL);
        
        [self setDocsets:@[]];
        [self setIndexingDocsets:@[]];
    }
    
    return self;
}

- (void)dealloc
{
    dispatch_release(_docsetArrayEditingQueue);
}

- (NSArray *)allDocsets
{
    return [_docsets arrayByAddingObjectsFromArray:_indexingDocsets];
}

- (BOOL)isEmpty
{
    return [_docsets count] == 0 && [_indexingDocsets count] == 0;
}

- (void)docSetDidBeginIndexing:(STADocSet *)docset
{
    dispatch_sync(_docsetArrayEditingQueue, ^()
                  {
                      if ([_docsets indexOfObjectIdenticalTo:docset] == NSNotFound)
                      {
                          [_indexingDocsets addObject:docset];
                      }
                  });
}

- (void)docSetDidFinishIndexing:(STADocSet *)docset
{
    dispatch_sync(_docsetArrayEditingQueue, ^()
                  {
                      [_indexingDocsets removeObjectIdenticalTo:docset];
                      [_docsets addObject:docset];
                  });
}

@end
