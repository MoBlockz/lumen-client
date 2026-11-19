// Entry point: runs when Minecraft loads the injected dylib.
#import "LMShared.h"

static BOOL gSafeMode = NO;
static CFTimeInterval gLaunch = 0;

BOOL LMSafeMode(void) { return gSafeMode; }
CFTimeInterval LMLaunchTime(void) { return gLaunch; }

NSString *LMGameVersion(void) {
    NSString *v = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return v.length ? v : @"unknown";
}

// Versions whose game-memory modules (Phase 2+) have been mapped. Empty in Phase 1,
// so those modules stay off instead of guessing and crashing.
BOOL LMGameVersionSupported(void) {
    static NSArray *supported;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ supported = @[]; });
    return [supported containsObject:LMGameVersion()];
}

__attribute__((constructor)) static void LMInit(void) {
    @autoreleasepool {
        gLaunch = CACurrentMediaTime();
        NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;

        // Crash guard: if the last launch died during startup, skip all hooks once.
        gSafeMode = [ud boolForKey:@"lm.bootInProgress"];
        [ud setBool:YES forKey:@"lm.bootInProgress"];
        void (^bootOK)(void) = ^{ [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"lm.bootInProgress"]; };
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), bootOK);
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                        object:nil queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(__unused NSNotification *n) { bootOK(); }];

        if (!gSafeMode) {
            @try { LMInstallHooks(); } @catch (__unused NSException *e) {}
        }

        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification
                                                        object:nil queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(__unused NSNotification *n) {
            @try { [[LMUI shared] start]; } @catch (__unused NSException *e) {}
        }];
    }
}
