@interface SliceSetting : NSObject
@property (readonly) NSString *prefix;

- (instancetype)initWithPrefix:(NSString *)prefix;
- (NSString *)getValueInDirectory:(NSString *)directory;
- (BOOL)setValueInDirectory:(NSString *)directory value:(NSString *)value;
@end