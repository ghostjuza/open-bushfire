NS_ASSUME_NONNULL_BEGIN

@interface Json : NSObject

/**
 Cast a json string to array.
 @param json json string.
 @returns NSDictionary | nil
 */
+ (nullable NSDictionary*)decode:(NSString*)json;

/**
 Cast json data object to array.
 @param file Path with filename.
 @returns NSDictionary | nil
 */
+ (nullable NSDictionary*)decodeData:(nullable NSData*)jsonData;

/**
 Decode json file  to array.
 @param file Path with filename.
 @returns NSDictionary | nil
 */
+ (nullable NSDictionary*)decodeFile:(NSString*)file;

+ (nullable NSDictionary*)decodeBundle:(NSString*)pathForResource;


/**
 Cast array to json string.
 @param dict Data array.
 @returns NSString | nil
 */
+ (nullable NSString*)encode:(nullable NSDictionary*)dict;

/**
 Cast array to json as data.
 @param dict Data array.
 @returns NSData | nil
 */
+ (nullable NSData*)encodeData:(nullable NSDictionary*)dict;

@end

NS_ASSUME_NONNULL_END
