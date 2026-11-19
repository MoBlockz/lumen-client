#import "LMShared.h"

NSString *const LMSettingsChangedNotification = @"LMSettingsChangedNotification";

@implementation LMSettings {
    NSMutableDictionary *_d;
    NSInteger _profile;
}

+ (instancetype)shared {
    static LMSettings *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [LMSettings new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _profile = [NSUserDefaults.standardUserDefaults integerForKey:@"lm.activeProfile"];
        if (_profile < 0 || _profile > 2) _profile = 0;
        [self load];
    }
    return self;
}

- (NSInteger)profile { return _profile; }

- (NSString *)storeKey { return [NSString stringWithFormat:@"lm.profile.%ld", (long)_profile]; }

- (void)load {
    NSDictionary *saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:[self storeKey]];
    _d = saved ? [saved mutableCopy] : [NSMutableDictionary dictionary];   // every module starts off
}

- (void)save { [NSUserDefaults.standardUserDefaults setObject:[_d copy] forKey:[self storeKey]]; }

- (void)notify {
    [NSNotificationCenter.defaultCenter postNotificationName:LMSettingsChangedNotification object:self];
}

- (void)switchToProfile:(NSInteger)profile {
    if (profile < 0 || profile > 2 || profile == _profile) return;
    [self save];
    _profile = profile;
    [NSUserDefaults.standardUserDefaults setInteger:profile forKey:@"lm.activeProfile"];
    [self load];
    [self notify];
}

- (void)resetProfile {
    _d = [NSMutableDictionary dictionary];
    [self save];
    [self notify];
}

- (BOOL)enabled:(NSString *)moduleId {
    LMModule *m = [LMModule withId:moduleId];
    if (m && !m.available) return NO;
    return [_d[[@"on." stringByAppendingString:moduleId]] boolValue];
}

- (void)setEnabled:(BOOL)on module:(NSString *)moduleId {
    [self setObject:@(on) forKey:[@"on." stringByAppendingString:moduleId]];
}

- (id)objectForKey:(NSString *)key { return _d[key]; }

- (void)setObjectQuietly:(id)obj forKey:(NSString *)key {
    if (obj) _d[key] = obj; else [_d removeObjectForKey:key];
    [self save];
}

- (void)setObject:(id)obj forKey:(NSString *)key {
    [self setObjectQuietly:obj forKey:key];
    [self notify];
}

- (NSInteger)integerForKey:(NSString *)key fallback:(NSInteger)fallback {
    id v = _d[key];
    return [v isKindOfClass:NSNumber.class] ? [v integerValue] : fallback;
}

- (double)doubleForKey:(NSString *)key fallback:(double)fallback {
    id v = _d[key];
    return [v isKindOfClass:NSNumber.class] ? [v doubleValue] : fallback;
}

@end

#pragma mark - Module catalogue

@implementation LMModule

static LMModule *M(NSString *ident, NSString *name, NSString *cat, NSInteger phase,
                   BOOL widget, BOOL gameData, BOOL risky, NSString *detail) {
    LMModule *m = [LMModule new];
    m.ident = ident; m.name = name; m.category = cat; m.phase = phase;
    m.hasWidget = widget; m.needsGameData = gameData; m.serverRisky = risky; m.detail = detail;
    return m;
}

- (BOOL)available {
    if (self.phase > 1) return NO;                       // not built yet
    if (self.needsGameData && !LMGameVersionSupported()) return NO;
    return YES;
}

+ (NSArray<NSString *> *)categories { return @[@"HUD", @"Visuals", @"Movement", @"Inventory"]; }

+ (NSArray<LMModule *> *)all {
    static NSArray *list; static dispatch_once_t once;
    dispatch_once(&once, ^{
        list = @[
            // HUD
            M(@"fps", @"FPS Display", @"HUD", 1, YES, NO, NO, @"Your current frames per second."),
            M(@"cps", @"CPS Display", @"HUD", 1, YES, NO, NO, @"Clicks/taps per second. Mouse shows left | right."),
            M(@"keystrokes", @"Keystrokes", @"HUD", 1, YES, NO, NO, @"Shows movement and action inputs (keyboard, mouse, controller, touch)."),
            M(@"clock", @"Clock", @"HUD", 1, YES, NO, NO, @"Real-world time."),
            M(@"session", @"Session Timer", @"HUD", 1, YES, NO, NO, @"How long the game has been open."),
            M(@"stopwatch", @"Stopwatch", @"HUD", 1, YES, NO, NO, @"Tap to start/stop, hold to reset."),
            M(@"speed", @"Speed Display", @"HUD", 2, YES, YES, NO, @"Movement speed in blocks per second."),
            M(@"coords", @"Coordinates", @"HUD", 2, YES, YES, NO, @"XYZ and facing direction."),
            M(@"debug", @"Debug Screen", @"HUD", 2, YES, YES, NO, @"FPS, memory, position, chunk, biome, light level."),
            M(@"armor", @"Armor HUD", @"HUD", 2, YES, YES, NO, @"Armor and held item durability."),
            M(@"potions", @"Potion Effects", @"HUD", 2, YES, YES, NO, @"Active effects with timers."),
            M(@"itemcount", @"Item Counter", @"HUD", 2, YES, YES, NO, @"Arrows, totems, blocks, potions."),
            M(@"minimap", @"Minimap", @"HUD", 4, YES, YES, YES, @"Live overhead map with waypoints."),
            // Visuals
            M(@"fpsunlock", @"FPS Unlocker", @"Visuals", 1, NO, NO, NO, @"Removes the 60 FPS cap, up to your screen's max (120 Hz on ProMotion)."),
            M(@"crosshair", @"Custom Crosshair", @"Visuals", 1, NO, NO, NO, @"Pick style, colour and size."),
            M(@"zoom", @"Zoom", @"Visuals", 3, NO, YES, NO, @"Zoom in with a shortcut button."),
            M(@"freelook", @"Free Look", @"Visuals", 3, NO, YES, YES, @"Look around without changing direction."),
            M(@"fullbright", @"Fullbright", @"Visuals", 3, NO, YES, YES, @"Everything fully lit."),
            M(@"motionblur", @"Motion Blur", @"Visuals", 3, NO, NO, NO, @"Blur on fast camera turns."),
            M(@"viewmodel", @"View Model", @"Visuals", 3, NO, YES, NO, @"Move/resize the held item."),
            M(@"environment", @"Environment Visuals", @"Visuals", 3, NO, YES, NO, @"Sky colour, rain, time - only on your screen."),
            M(@"chunkborders", @"Chunk Borders", @"Visuals", 3, NO, YES, NO, @"Outlines chunk edges."),
            M(@"hitboxes", @"Hitboxes", @"Visuals", 3, NO, YES, YES, @"Boxes around entities."),
            M(@"shaders", @"Shader Loader", @"Visuals", 3, NO, NO, YES, @"Load iOS material.bin shader packs."),
            M(@"lowfire", @"Low Fire", @"Visuals", 3, NO, YES, NO, @"Smaller fire overlay."),
            M(@"hurtcam", @"No Hurt Cam", @"Visuals", 3, NO, YES, NO, @"Turns off damage camera shake."),
            // Movement & utilities
            M(@"autosprint", @"Auto-Sprint", @"Movement", 2, NO, YES, NO, @"Sprint whenever moving forward."),
            M(@"togglesneak", @"Toggle Sneak", @"Movement", 2, NO, YES, NO, @"Tap once to keep sneaking."),
            M(@"waypoints", @"Waypoints", @"Movement", 2, NO, YES, NO, @"Named markers with distance, saved per world."),
            M(@"distance", @"Distance Measure", @"Movement", 2, NO, YES, NO, @"Measure between two points."),
            M(@"shortcuts", @"Quick Shortcuts", @"Movement", 2, NO, YES, NO, @"One-tap perspective, drop item, hide HUD."),
            // Inventory
            M(@"shulker", @"Shulker Preview", @"Inventory", 3, NO, YES, NO, @"See inside shulker boxes."),
            M(@"iteminfo", @"Item Info", @"Inventory", 3, NO, YES, NO, @"Extra item tooltips."),
            M(@"dropprevent", @"Drop Prevention", @"Inventory", 3, NO, YES, NO, @"Stops dropping valuable items by accident."),
        ];
    });
    return list;
}

+ (LMModule *)withId:(NSString *)ident {
    for (LMModule *m in [self all]) if ([m.ident isEqualToString:ident]) return m;
    return nil;
}

@end
