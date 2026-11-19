// Lumen Client - shared declarations
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <GameController/GameController.h>
#include <stdatomic.h>

#define LM_VERSION @"0.1.0"

extern NSString *const LMSettingsChangedNotification;

#pragma mark - Settings (per profile, saved on device)

@interface LMSettings : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) NSInteger profile;          // 0..2
- (void)switchToProfile:(NSInteger)profile;
- (void)resetProfile;
- (BOOL)enabled:(NSString *)moduleId;
- (void)setEnabled:(BOOL)on module:(NSString *)moduleId;
- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)obj forKey:(NSString *)key;           // saves + notifies
- (void)setObjectQuietly:(id)obj forKey:(NSString *)key;    // saves, no notify
- (NSInteger)integerForKey:(NSString *)key fallback:(NSInteger)fallback;
- (double)doubleForKey:(NSString *)key fallback:(double)fallback;
@end

#pragma mark - Module catalogue

@interface LMModule : NSObject
@property (nonatomic, copy) NSString *ident, *name, *detail, *category;
@property (nonatomic) NSInteger phase;        // build phase that delivers it
@property (nonatomic) BOOL hasWidget;         // draggable HUD element
@property (nonatomic) BOOL needsGameData;     // reads game memory (version-locked)
@property (nonatomic) BOOL serverRisky;       // switched off by "Server-safe"
@property (nonatomic, readonly) BOOL available;
+ (NSArray<LMModule *> *)all;
+ (NSArray<NSString *> *)categories;
+ (LMModule *)withId:(NSString *)ident;
@end

#pragma mark - Hooks / frame stats

extern _Atomic(uint64_t) LMFrameCounter;
extern NSInteger LMHookCount;
extern NSInteger LMScreenMaxFPSCached;
NSUInteger LMDisplayLinkCount(void);
void LMInstallHooks(void);
void LMApplyFrameUnlock(void);

#pragma mark - Input

@interface LMInput : NSObject
+ (instancetype)shared;
- (void)handleEvent:(UIEvent *)event;
- (void)poll;
@property (nonatomic, readonly) BOOL keyW, keyA, keyS, keyD, keySpace, keyShift, mouseL, mouseR;
@property (nonatomic, readonly) BOOL mouseMode;               // mouse connected
@property (nonatomic, readonly, copy) NSString *activeSource;
@property (nonatomic, readonly) uint64_t touchesSeen;
- (NSInteger)cpsLeft;
- (NSInteger)cpsRight;
@end

#pragma mark - UI

@interface LMUI : NSObject
+ (instancetype)shared;
- (void)start;
- (void)toast:(NSString *)text;
@property (nonatomic, readonly) UIWindow *overlayWindow;
@property (nonatomic, readonly) double currentFPS;
@end

#pragma mark - Misc

BOOL LMSafeMode(void);
CFTimeInterval LMLaunchTime(void);
NSString *LMGameVersion(void);
BOOL LMGameVersionSupported(void);
