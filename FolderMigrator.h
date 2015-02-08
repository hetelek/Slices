@interface FolderMigrator : NSObject
@property NSArray *sourceFolderPaths;
@property NSArray *destinationFolderPaths;
@property NSArray *ignoreSuffixes;

+ (BOOL)migrateDirectory:(NSString *)sourceDirectory toDirectory:(NSString *)destinationDirectory ignoreSuffixes:(NSArray *)ignoreSuffixes;

- (instancetype)initWithSourcePath:(NSString *)sourceFolderPath destinationPath:(NSString *)destinationFolderPath;
- (BOOL)executeMigration;
@end