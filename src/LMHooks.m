// Version-independent hooks: only public Apple classes, no game offsets.
#import "LMShared.h"
#import <objc/runtime.h>

_Atomic(uint64_t) LMFrameCounter = 0;
NSInteger LMHookCount = 0;
NSInteger LMScreenMaxFPSCached = 0;

static NSHashTable *gLinks;          // every CADisplayLink the game creates (weak)
static volatile BOOL gUnlockOn = NO;
static char kOrigFPSKey, kOrigRangeKey;

typedef void (*SendEventFn)(id, SEL, UIEvent *);
typedef id (*NextDrawableFn)(id, SEL);
typedef CADisplayLink *(*LinkCreateFn)(id, SEL, id, SEL);
typedef void (*SetFPSFn)(id, SEL, NSInteger);
typedef void (*SetRangeFn)(id, SEL, CAFrameRateRange);

static SendEventFn gOrigSendEvent;
static NextDrawableFn gOrigNextDrawable;
static LinkCreateFn gOrigLinkCreate;
static SetFPSFn gOrigLinkSetFPS, gOrigMTKSetFPS;
static SetRangeFn gOrigLinkSetRange;

static NSInteger LMTargetFPS(void) { return LMScreenMaxFPSCached > 0 ? LMScreenMaxFPSCached : 120; }

NSUInteger LMDisplayLinkCount(void) {
    @synchronized (gLinks) { return gLinks.allObjects.count; }
}

static void LMForceLink(CADisplayLink *l) {
    NSInteger fps = LMTargetFPS();
    if (gOrigLinkSetRange) {
        gOrigLinkSetRange(l, @selector(setPreferredFrameRateRange:), CAFrameRateRangeMake(fps, fps, fps));
    } else if (gOrigLinkSetFPS) {
        gOrigLinkSetFPS(l, @selector(setPreferredFramesPerSecond:), fps);
    }
}

static void LMRestoreLink(CADisplayLink *l) {
    NSArray *range = objc_getAssociatedObject(l, &kOrigRangeKey);
    NSNumber *fps = objc_getAssociatedObject(l, &kOrigFPSKey);
    if (range.count == 3 && gOrigLinkSetRange) {
        gOrigLinkSetRange(l, @selector(setPreferredFrameRateRange:),
                          CAFrameRateRangeMake([range[0] floatValue], [range[1] floatValue], [range[2] floatValue]));
    } else if (gOrigLinkSetFPS) {
        gOrigLinkSetFPS(l, @selector(setPreferredFramesPerSecond:), fps ? fps.integerValue : 0);
    }
}

static void LMVisitViews(UIView *v, void (^fn)(UIView *)) {
    fn(v);
    for (UIView *s in v.subviews) LMVisitViews(s, fn);
}

void LMApplyFrameUnlock(void) {
    BOOL on = [[LMSettings shared] enabled:@"fpsunlock"];
    gUnlockOn = on;
    NSArray *links;
    @synchronized (gLinks) { links = gLinks.allObjects; }
    for (CADisplayLink *l in links) { if (on) LMForceLink(l); else LMRestoreLink(l); }

    Class mtk = NSClassFromString(@"MTKView");
    if (!mtk || !gOrigMTKSetFPS) return;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            LMVisitViews(w, ^(UIView *v) {
                if (![v isKindOfClass:mtk]) return;
                NSNumber *orig = objc_getAssociatedObject(v, &kOrigFPSKey);
                NSInteger fps = on ? LMTargetFPS() : (orig ? orig.integerValue : 60);
                gOrigMTKSetFPS(v, @selector(setPreferredFramesPerSecond:), fps);
            });
        }
    }
}

static IMP LMReplace(Method m, id block) {
    if (!m) return NULL;
    LMHookCount++;
    return method_setImplementation(m, imp_implementationWithBlock(block));
}

void LMInstallHooks(void) {
    gLinks = [NSHashTable weakObjectsHashTable];

    // 1. Input: see every touch / key press before the game does (read-only).
    gOrigSendEvent = (SendEventFn)LMReplace(class_getInstanceMethod(UIApplication.class, @selector(sendEvent:)),
        ^(id app, UIEvent *e) {
            @try { [[LMInput shared] handleEvent:e]; } @catch (__unused NSException *x) {}
            gOrigSendEvent(app, @selector(sendEvent:), e);
        });

    // 2. Frame counter: the game asks Metal for one drawable per rendered frame.
    gOrigNextDrawable = (NextDrawableFn)LMReplace(class_getInstanceMethod(CAMetalLayer.class, @selector(nextDrawable)),
        ^id(id layer) {
            atomic_fetch_add_explicit(&LMFrameCounter, 1, memory_order_relaxed);
            return gOrigNextDrawable(layer, @selector(nextDrawable));
        });

    // 3. FPS unlock: track display links and override the frame-rate caps the game sets.
    gOrigLinkCreate = (LinkCreateFn)LMReplace(class_getClassMethod(CADisplayLink.class, @selector(displayLinkWithTarget:selector:)),
        ^CADisplayLink *(id cls, id target, SEL sel) {
            CADisplayLink *l = gOrigLinkCreate(cls, @selector(displayLinkWithTarget:selector:), target, sel);
            if (l) {
                @synchronized (gLinks) { [gLinks addObject:l]; }
                if (gUnlockOn) LMForceLink(l);
            }
            return l;
        });

    gOrigLinkSetFPS = (SetFPSFn)LMReplace(class_getInstanceMethod(CADisplayLink.class, @selector(setPreferredFramesPerSecond:)),
        ^(CADisplayLink *l, NSInteger fps) {
            objc_setAssociatedObject(l, &kOrigFPSKey, @(fps), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(l, &kOrigRangeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (gUnlockOn) { LMForceLink(l); return; }
            gOrigLinkSetFPS(l, @selector(setPreferredFramesPerSecond:), fps);
        });

    gOrigLinkSetRange = (SetRangeFn)LMReplace(class_getInstanceMethod(CADisplayLink.class, @selector(setPreferredFrameRateRange:)),
        ^(CADisplayLink *l, CAFrameRateRange r) {
            objc_setAssociatedObject(l, &kOrigRangeKey, @[@(r.minimum), @(r.maximum), @(r.preferred)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (gUnlockOn) { LMForceLink(l); return; }
            gOrigLinkSetRange(l, @selector(setPreferredFrameRateRange:), r);
        });

    Class mtk = NSClassFromString(@"MTKView");
    if (mtk) {
        gOrigMTKSetFPS = (SetFPSFn)LMReplace(class_getInstanceMethod(mtk, @selector(setPreferredFramesPerSecond:)),
            ^(id view, NSInteger fps) {
                objc_setAssociatedObject(view, &kOrigFPSKey, @(fps), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                gOrigMTKSetFPS(view, @selector(setPreferredFramesPerSecond:), gUnlockOn ? LMTargetFPS() : fps);
            });
    }
}
