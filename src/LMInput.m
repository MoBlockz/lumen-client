// Read-only input tracking for CPS and Keystrokes.
// Nothing here consumes or changes input - the game still gets every event.
#import "LMShared.h"

@interface LMInput ()
@property (nonatomic, readwrite) BOOL keyW, keyA, keyS, keyD, keySpace, keyShift, mouseL, mouseR;
@property (nonatomic, readwrite) BOOL mouseMode;
@property (nonatomic, readwrite, copy) NSString *activeSource;
@property (nonatomic, readwrite) uint64_t touchesSeen;
@end

@implementation LMInput {
    NSMutableArray<NSNumber *> *_leftClicks, *_rightClicks;
    NSMutableSet<NSNumber *> *_keys;          // HID usages from UIPress events
    BOOL _gcL, _gcR, _padAtk, _padUse;        // last polled states (edge detection)
    BOOL _ptrL, _ptrR;                        // UIKit pointer buttons
    void *_moveTouch;                         // touch driving the movement zone
    CGPoint _moveOrigin;
    BOOL _tW, _tA, _tS, _tD;
    NSInteger _tapsDown;
}

+ (instancetype)shared {
    static LMInput *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [LMInput new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _leftClicks = [NSMutableArray array];
        _rightClicks = [NSMutableArray array];
        _keys = [NSMutableSet set];
        _activeSource = @"Touch";
    }
    return self;
}

- (void)click:(BOOL)right source:(NSString *)src {
    [(right ? _rightClicks : _leftClicks) addObject:@(CACurrentMediaTime())];
    self.activeSource = src;
}

#pragma mark Events (main thread, from UIApplication sendEvent:)

- (void)handleEvent:(UIEvent *)event {
    UIWindow *overlay = [LMUI shared].overlayWindow;

    if (event.type == UIEventTypePresses) {
        for (UIPress *p in ((UIPressesEvent *)event).allPresses) {
            if (!p.key) continue;
            NSNumber *k = @(p.key.keyCode);
            if (p.phase == UIPressPhaseBegan) { [_keys addObject:k]; self.activeSource = @"Keyboard & Mouse"; }
            else if (p.phase == UIPressPhaseEnded || p.phase == UIPressPhaseCancelled) [_keys removeObject:k];
        }
        return;
    }
    if (event.type != UIEventTypeTouches) return;

    BOOL mouseConnected = GCMouse.current != nil;
    for (UITouch *t in event.allTouches) {
        if (overlay && t.window == overlay) continue;          // our own menu / buttons

        if (t.type == UITouchTypeIndirectPointer) {
            if (t.phase == UITouchPhaseBegan) {
                BOOL right = (event.buttonMask & UIEventButtonMaskSecondary) != 0;
                if (right) _ptrR = YES; else _ptrL = YES;
                if (!mouseConnected) [self click:right source:@"Keyboard & Mouse"];
            } else if (t.phase == UITouchPhaseEnded || t.phase == UITouchPhaseCancelled) {
                _ptrL = _ptrR = NO;
            }
            continue;
        }
        if (mouseConnected) continue;                          // avoid double counting

        void *tid = (__bridge void *)t;
        CGPoint p = [t locationInView:nil];
        CGSize sz = t.window.bounds.size;
        switch (t.phase) {
            case UITouchPhaseBegan:
                self.touchesSeen++;
                if (p.x < sz.width * 0.35 && p.y > sz.height * 0.45 && !_moveTouch) {
                    _moveTouch = tid; _moveOrigin = p;           // movement pad / joystick area
                } else {
                    _tapsDown++;
                    [self click:NO source:@"Touch"];
                }
                break;
            case UITouchPhaseMoved:
                if (tid == _moveTouch) {
                    CGFloat dx = p.x - _moveOrigin.x, dy = p.y - _moveOrigin.y;
                    _tW = dy < -14; _tS = dy > 14; _tA = dx < -14; _tD = dx > 14;
                }
                break;
            case UITouchPhaseEnded:
            case UITouchPhaseCancelled:
                if (tid == _moveTouch) { _moveTouch = NULL; _tW = _tA = _tS = _tD = NO; }
                else if (_tapsDown > 0) _tapsDown--;
                break;
            default: break;
        }
    }
}

#pragma mark Polling (main thread, ~200 Hz)

static BOOL KB(GCKeyboardInput *kb, GCKeyCode code) {
    return kb && [kb buttonForKeyCode:code].isPressed;
}

- (void)poll {
    CFTimeInterval now = CACurrentMediaTime();

    GCMouse *mouse = GCMouse.current;
    self.mouseMode = mouse != nil;
    BOOL mL = mouse && mouse.mouseInput.leftButton.isPressed;
    BOOL mR = mouse && mouse.mouseInput.rightButton.isPressed;
    if (mL && !_gcL) [self click:NO source:@"Keyboard & Mouse"];
    if (mR && !_gcR) [self click:YES source:@"Keyboard & Mouse"];
    _gcL = mL; _gcR = mR;

    GCKeyboardInput *kb = GCKeyboard.coalescedKeyboard.keyboardInput;
    BOOL w = [_keys containsObject:@(UIKeyboardHIDUsageKeyboardW)] || KB(kb, GCKeyCodeKeyW);
    BOOL a = [_keys containsObject:@(UIKeyboardHIDUsageKeyboardA)] || KB(kb, GCKeyCodeKeyA);
    BOOL s = [_keys containsObject:@(UIKeyboardHIDUsageKeyboardS)] || KB(kb, GCKeyCodeKeyS);
    BOOL d = [_keys containsObject:@(UIKeyboardHIDUsageKeyboardD)] || KB(kb, GCKeyCodeKeyD);
    BOOL space = [_keys containsObject:@(UIKeyboardHIDUsageKeyboardSpacebar)] || KB(kb, GCKeyCodeSpacebar);
    BOOL shift = [_keys containsObject:@(UIKeyboardHIDUsageKeyboardLeftShift)] || KB(kb, GCKeyCodeLeftShift);

    GCExtendedGamepad *pad = GCController.current.extendedGamepad;
    BOOL pAtk = NO, pUse = NO;
    if (pad) {
        float x = pad.leftThumbstick.xAxis.value, y = pad.leftThumbstick.yAxis.value;
        if (y > 0.4f) w = YES;
        if (y < -0.4f) s = YES;
        if (x < -0.4f) a = YES;
        if (x > 0.4f) d = YES;
        if (pad.buttonA.isPressed) space = YES;
        if (pad.rightThumbstickButton.isPressed) shift = YES;
        pAtk = pad.rightTrigger.isPressed;
        pUse = pad.leftTrigger.isPressed;
        if (pAtk && !_padAtk) [self click:NO source:@"Controller"];
        if (pUse && !_padUse) [self click:YES source:@"Controller"];
        if (fabsf(x) > 0.4f || fabsf(y) > 0.4f) self.activeSource = @"Controller";
    }
    _padAtk = pAtk; _padUse = pUse;

    self.keyW = w || _tW;
    self.keyA = a || _tA;
    self.keyS = s || _tS;
    self.keyD = d || _tD;
    self.keySpace = space;
    self.keyShift = shift;
    self.mouseL = mL || _ptrL || pAtk || _tapsDown > 0;
    self.mouseR = mR || _ptrR || pUse;

    while (_leftClicks.count && now - _leftClicks.firstObject.doubleValue > 1.0) [_leftClicks removeObjectAtIndex:0];
    while (_rightClicks.count && now - _rightClicks.firstObject.doubleValue > 1.0) [_rightClicks removeObjectAtIndex:0];
}

- (NSInteger)cpsLeft { return (NSInteger)_leftClicks.count; }
- (NSInteger)cpsRight { return (NSInteger)_rightClicks.count; }

@end
