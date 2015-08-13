@interface FolderMigrator : NSObject
@property NSArray *sourceFolderPaths;
@property NSArray *destinationFolderPaths;
@property NSArray *ignoreSuffixes;
@property NSArray *ignorePrefixes;

+ (BOOL)migrateDirectory:(NSString *)sourceDirectory toDirectory:(NSString *)destinationDirectory ignorePrefixes:(NSArray *)ignorePrefixes ignoreSuffixes:(NSArray *)ignoreSuffixes;
+ (BOOL)migrateDirectory:(NSString *)sourceDirectory toDirectory:(NSString *)destinationDirectory ignoreSuffixes:(NSArray *)ignoreSuffixes;
+ (BOOL)migrateDirectory:(NSString *)sourceDirectory toDirectory:(NSString *)destinationDirectory ignorePrefixes:(NSArray *)ignorePrefixes;

- (instancetype)initWithSourcePath:(NSString *)sourceFolderPath destinationPath:(NSString *)destinationFolderPath;
- (BOOL)executeMigration;
@end