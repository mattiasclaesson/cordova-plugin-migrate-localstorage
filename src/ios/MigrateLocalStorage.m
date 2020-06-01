#import "MigrateLocalStorage.h"

@implementation MigrateLocalStorage

- (BOOL) copyFromIndexedDB:(NSString*)src to:(NSString*)dest
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* appLibraryFolder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];

    // create path to dest
    if (![fileManager createDirectoryAtPath:[dest stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil]) {
        return NO;
    }

    NSArray* srcFiles = [fileManager contentsOfDirectoryAtPath:src error:nil];
    BOOL success = YES;
    for (NSString *file in srcFiles) {
        NSError *err;
        NSString* srcFile = [appLibraryFolder stringByAppendingPathComponent:@"WebKit/LocalStorage/___IndexedDB"];
        srcFile = [srcFile stringByAppendingPathComponent:file];
        NSString* destFile = [appLibraryFolder stringByAppendingPathComponent:@"WebKit/WebsiteData/IndexedDB"];
        destFile = [destFile stringByAppendingPathComponent:file];
        BOOL fileSuccess = [fileManager copyItemAtPath:srcFile toPath:destFile error:&err];
        success = success && fileSuccess;
    }
    return success;
}

- (BOOL) copyFromLocalStorage:(NSString*)src to:(NSString*)dest
{
    NSFileManager* fileManager = [NSFileManager defaultManager];

    // Bail out if source file does not exist
    if (![fileManager fileExistsAtPath:src]) {
        return NO;
    }

    // Bail out if dest file exists
    if ([fileManager fileExistsAtPath:dest]) {
        return NO;
    }

    // create path to dest
    if (![fileManager createDirectoryAtPath:[dest stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil]) {
        return NO;
    }

    // copy src to dest
    return [fileManager copyItemAtPath:src toPath:dest error:nil];
}

- (BOOL) migrateLocalStorage
{
    // Migrate UIWebView local storage files to WKWebView. Adapted from
    // https://github.com/Telerik-Verified-Plugins/WKWebView/blob/master/src/ios/MyMainViewController.m

    NSString* appLibraryFolder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* original;

    if ([[NSFileManager defaultManager] fileExistsAtPath:[appLibraryFolder stringByAppendingPathComponent:@"WebKit/LocalStorage/file__0.localstorage"]]) {
        original = [appLibraryFolder stringByAppendingPathComponent:@"WebKit/LocalStorage"];
    } else {
        original = [appLibraryFolder stringByAppendingPathComponent:@"Caches"];
    }

    original = [original stringByAppendingPathComponent:@"file__0.localstorage"];

    NSString* target = [[NSString alloc] initWithString: [appLibraryFolder stringByAppendingPathComponent:@"WebKit"]];

#if TARGET_IPHONE_SIMULATOR
    // the simulutor squeezes the bundle id into the path
    NSString* bundleIdentifier = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    target = [target stringByAppendingPathComponent:bundleIdentifier];
#endif

    target = [target stringByAppendingPathComponent:@"WebsiteData/LocalStorage/file__0.localstorage"];

    // Only copy data if no existing localstorage data exists yet for wkwebview
    if (![[NSFileManager defaultManager] fileExistsAtPath:target]) {
        NSLog(@"No existing localstorage data found for WKWebView. Migrating data from UIWebView");
        BOOL success1 = [self copyFromLocalStorage:original to:target];
        BOOL success2 = [self copyFromLocalStorage:[original stringByAppendingString:@"-shm"] to:[target stringByAppendingString:@"-shm"]];
        BOOL success3 = [self copyFromLocalStorage:[original stringByAppendingString:@"-wal"] to:[target stringByAppendingString:@"-wal"]];
        return success1 && success2 && success3;
    }
    else {
        return NO;
    }
}

// FIXME clean this mess up
- (BOOL) migrateIndexedDB
{
  NSString* webViewEngineClass = [ self.commandDelegate.settings objectForKey:[@"CordovaWebViewEngine" lowercaseString]];
    if ([webViewEngineClass isEqualToString:@"CDVUIWebViewEngine"]) {
        return NO;
    } else {
        NSString* appLibraryFolder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];

        NSFileManager* fileManager = [NSFileManager defaultManager];

        NSString* original = [appLibraryFolder stringByAppendingPathComponent:@"WebKit/LocalStorage/___IndexedDB"];

        NSString* target = [[NSString alloc] initWithString: [appLibraryFolder stringByAppendingPathComponent:@"WebKit/WebsiteData/IndexedDB"]];

        if ([[NSFileManager defaultManager] fileExistsAtPath:original]) {
            NSLog(@"No existing indexed db data found for WKWebView. Migrating data from UIWebView");
            BOOL copySuccessful = [self copyFromIndexedDB:original to:target];
            if (copySuccessful) {
                NSLog(@"IndexedDB migration copy successful");
                NSArray* srcFiles = [fileManager contentsOfDirectoryAtPath:original error:nil];
                BOOL deleted = YES;
                for (NSString *file in srcFiles) {
                    NSError *err;
                    NSString* srcFile = [appLibraryFolder stringByAppendingPathComponent:@"WebKit/LocalStorage/___IndexedDB"];
                    srcFile = [srcFile stringByAppendingPathComponent:file];
                    BOOL deleteSuccessful = [[NSFileManager defaultManager] removeItemAtPath:original error:&err];
                    deleted = deleted && deleteSuccessful;
                }
                if (deleted) {
                    NSLog(@"IndexedDB migration deletion successful");
                } else {
                    NSLog(@"IndexedDB migration deletion failed");
                }
                return deleted;
            } else {
                NSLog(@"IndexedDB migration copy failed");
                return NO;
            }
        } else {
            NSLog(@"No existing indexed db data found for UIWebview");
            return NO;
        }
    }
    return NO;
}

- (void) pluginInitialize
{
    [self migrateLocalStorage];
    BOOL lsResult = [self migrateLocalStorage];
    BOOL idbResult = [self migrateIndexedDB];
    if (lsResult) {
        NSLog(@"Successfully migrated localstorage");
    }
    if (idbResult) {
        NSLog(@"Successfully migrated indexed db");
    }
}

@end
