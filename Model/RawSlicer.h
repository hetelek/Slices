#import <spawn.h>

#import "FolderMigrator.h"
#import "SliceSetting.h"

@interface RawSlicer : NSObject
@property (nonatomic, readonly) NSArray *slices;
@property (nonatomic) NSString *currentSlice;

@property NSString *workingDirectory;
@property NSString *slicesDirectory;

- (instancetype)initWithWorkingDirectory:(NSString *)workingDirectory slicesDirectory:(NSString *)slicesDirectory;

- (BOOL)switchToSlice:(NSString *)targetSliceName ignoreSuffixes:(NSArray *)ignoreSuffixes;
- (BOOL)createSlice:(NSString *)newSliceName ignoreSuffixes:(NSArray *)ignoreSuffixes;
- (BOOL)deleteSlice:(NSString *)sliceName ignoreSuffixes:(NSArray *)ignoreSuffixes;
- (BOOL)renameSlice:(NSString *)originaSliceName toName:(NSString *)targetSliceName;
@end
