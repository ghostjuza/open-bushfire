typedef void (^SweeperManagerBlock)(NSNumber *,NSError *);

@interface SweeperManager : NSObject

- (void)cleanupWithCompletion;
- (void)cleanupWithCompletion:(SweeperManagerBlock)block;

+ (NSArray*)getCookiesList;
+ (NSArray*)getLocalStorageList;
+ (NSArray*)getFlashCookiesList;
+ (NSArray*)getCacheList;
+ (NSArray*)getPreviewList;
+ (NSArray*)getHistoryList;
+ (NSArray*)getTopSitesList;
+ (NSArray*)getFormsList;
+ (NSArray*)getDownloadsList;
+ (NSArray*)getWebPageIconsList;
+ (NSArray*)getLocationList;
+ (NSArray*)getBushfireJunkList;
+ (NSArray*)getOfflineDataList;

+ (NSArray*)getMailDownloadsList;

@end
