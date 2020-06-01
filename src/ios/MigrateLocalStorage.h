#import <Cordova/CDVPlugin.h>

@interface MigrateLocalStorage : CDVPlugin {}

- (BOOL) copyFromIndexedDB:(NSString*)src to:(NSString*)dest;
- (BOOL) copyFromLocalStorage:(NSString*)src to:(NSString*)dest;
- (BOOL) migrateLocalStorage;
- (BOOL) migrateIndexedDB;
- (void) pluginInitialize;

@end
