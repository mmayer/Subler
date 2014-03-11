//
//  SBQueue.h
//  Subler
//
//  Created by Damiano Galassi on 27/02/14.
//
//

#import <Foundation/Foundation.h>

#import <IOKit/pwr_mgt/IOPMLib.h>

@class SBQueueItem;
@class MP42File;

typedef NS_ENUM(NSUInteger, SBQueueStatus) {
    SBQueueStatusUnknown = 0,
    SBQueueStatusWorking,
    SBQueueStatusCompleted,
    SBQueueStatusFailed,
    SBQueueStatusCancelled,
};

@interface SBQueue : NSObject {
    @private
    dispatch_queue_t   _queue;
    SBQueueStatus      _status;

    MP42File           *_currentMP4;
    NSMutableArray     *_items;
    NSURL              *_URL;
    NSURL              *_destination;

    IOPMAssertionID _assertionID;
    IOReturn        _io_success;
    BOOL            _cancelled;

    BOOL _optimize;
    BOOL _fetchMetadata;
    BOOL _organizeGroups;
}

@property (atomic, readonly) SBQueueStatus status;

@property (atomic, copy) NSURL *destination;
@property (atomic) BOOL optimize;
@property (atomic) BOOL fetchMetadata;
@property (atomic) BOOL organizeGroups;

- (instancetype)initWithURL:(NSURL *)queueURL;

- (void)start;
- (void)stop;

- (void)addItem:(SBQueueItem *)item;

- (NSUInteger)count;
- (NSUInteger)readyCount;

- (SBQueueItem *)itemAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfItem:(SBQueueItem *)item;
- (NSArray *)itemsAtIndexes:(NSIndexSet *)indexes;

- (void)insertItem:(SBQueueItem *)anItem atIndex:(NSUInteger)index;

- (void)removeItemsAtIndexes:(NSIndexSet *)indexes;
- (void)removeItem:(SBQueueItem *)item;

- (NSIndexSet *)removeCompletedItems;

- (BOOL)saveQueueToDisk;

@end
