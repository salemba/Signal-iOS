//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

#import <SignalMessaging/OWSDatabaseMigration.h>
#import <SignalServiceKit/OWSPrimaryStorage.h>
#import <SignalServiceKit/SSKEnvironment.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSDatabaseMigration

+ (SDSKeyValueStore *)keyValueStore
{
    static SDSKeyValueStore *keyValueStore = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keyValueStore = [[SDSKeyValueStore alloc] initWithCollection:OWSDatabaseMigration.collection];
    });
    return keyValueStore;
}

- (BOOL)shouldSave
{
    return YES;
}

+ (NSString *)migrationId
{
    OWSAbstractMethod();

    return @"";
}

+ (NSString *)collection
{
    // We want all subclasses in the same collection
    return @"OWSDatabaseMigration";
}

- (void)runUpWithCompletion:(OWSDatabaseMigrationCompletion)completion
{
    OWSAbstractMethod();
}

- (void)markAsCompleteWithSneakyTransaction
{
    OWSAbstractMethod();
}

- (void)markAsCompleteWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    OWSLogInfo(@"Completed migration %@", [self class]);

    [OWSDatabaseMigration.keyValueStore setBool:YES key:self.class.migrationId transaction:transaction];
}

- (BOOL)isCompleteWithSneakyTransaction
{
    OWSAbstractMethod();

    return NO;
}

- (BOOL)isCompleteWithTransaction:(SDSAnyReadTransaction *)transaction
{
    return [OWSDatabaseMigration.keyValueStore getBool:self.class.migrationId defaultValue:NO transaction:transaction];
}

@end

#pragma mark -

@implementation YDBDatabaseMigration

#pragma mark - Dependencies

- (OWSPrimaryStorage *)primaryStorage
{
    OWSAssertDebug(SSKEnvironment.shared.primaryStorage);

    return SSKEnvironment.shared.primaryStorage;
}

#pragma mark -

- (void)runUpWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    OWSAbstractMethod();
}

- (void)runUpWithCompletion:(OWSDatabaseMigrationCompletion)completion
{
    OWSAssertDebug(completion);

    OWSDatabaseConnection *dbConnection = (OWSDatabaseConnection *)self.primaryStorage.newDatabaseConnection;

    [dbConnection
        asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *_Nonnull transaction) {
            [self runUpWithTransaction:transaction];
        }
        completionBlock:^{
            [dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                [self markAsCompleteWithTransaction:transaction.asAnyWrite];
            }];

            completion();
        }];
}

- (void)markAsCompleteWithSneakyTransaction
{
    // GRDB TODO: Which kind of transaction we should use depends on whether or not
    //            we are pre- or post- the YDB-to-GRDB migration.
    [self.ydbReadWriteConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [self markAsCompleteWithTransaction:transaction.asAnyWrite];
    }];
}

- (BOOL)isCompleteWithSneakyTransaction
{
    // GRDB TODO: Which kind of transaction we should use depends on whether or not
    //            we are pre- or post- the YDB-to-GRDB migration.
    __block BOOL result;
    [self.ydbReadConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        result = [self isCompleteWithTransaction:transaction.asAnyRead];
    }];
    return result;
}

#pragma mark - Database Connections

+ (YapDatabaseConnection *)ydbReadConnection
{
    return self.ydbReadWriteConnection;
}

+ (YapDatabaseConnection *)ydbReadWriteConnection
{
    return SSKEnvironment.shared.migrationDBConnection;
}

- (YapDatabaseConnection *)ydbReadConnection
{
    return YDBDatabaseMigration.ydbReadConnection;
}

- (YapDatabaseConnection *)ydbReadWriteConnection
{
    return YDBDatabaseMigration.ydbReadWriteConnection;
}

@end

NS_ASSUME_NONNULL_END
