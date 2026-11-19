// Overlay UI: floating button, module menu, HUD widgets, Edit HUD, crosshair, toasts.
#import "LMShared.h"

@interface LMUI ()
- (void)layoutOverlay;
@end

static UIColor *LMAccent(void) { return [UIColor colorWithRed:0.42 green:0.78 blue:1.0 alpha:1]; }

static UILabel *LMLabel(NSString *text, CGFloat size, UIFontWeight weight, UIColor *color) {
    UILabel *l = [UILabel new];
    l.text = text;
    l.font = [UIFont systemFontOfSize:size weight:weight];
    l.textColor = color;
    l.numberOfLines = 0;
    return l;
}

static UIButton *LMButton(NSString *title, void (^handler)(void)) {
    UIButtonConfiguration *c = [UIButtonConfiguration filledButtonConfiguration];
    c.title = title;
    c.baseBackgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    c.baseForegroundColor = UIColor.whiteColor;
    c.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    return [UIButton buttonWithConfiguration:c primaryAction:[UIAction actionWithHandler:^(__kindof UIAction *a) { handler(); }]];
}

static NSString *LMDuration(double t, BOOL tenths) {
    if (t < 0) t = 0;
    long s = (long)t, h = s / 3600, m = (s / 60) % 60, sec = s % 60;
    if (tenths) {
        int d = (int)((t - floor(t)) * 10);
        return h ? [NSString stringWithFormat:@"%ld:%02ld:%02ld.%d", h, m, sec, d]
                 : [NSString stringWithFormat:@"%02ld:%02ld.%d", m, sec, d];
    }
    return h ? [NSString stringWithFormat:@"%ld:%02ld:%02ld", h, m, sec]
             : [NSString stringWithFormat:@"%02ld:%02ld", m, sec];
}

#pragma mark - Window plumbing

@interface LMPassWindow : UIWindow
@end
@implementation LMPassWindow
// Touches that don't land on our controls fall through to Minecraft.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:point withEvent:event];
    if (v == self || v == self.rootViewController.view) return nil;
    return v;
}
@end

@interface LMRootView : UIView
@end
@implementation LMRootView
- (void)layoutSubviews { [super layoutSubviews]; [[LMUI shared] layoutOverlay]; }
@end

@interface LMRootVC : UIViewController
@end
@implementation LMRootVC
- (void)loadView { self.view = [LMRootView new]; self.view.backgroundColor = UIColor.clearColor; }
- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures { return UIRectEdgeAll; }
@end

#pragma mark - HUD widgets

@interface LMWidget : UIView
@property (nonatomic, copy) NSString *ident;
@property (nonatomic, strong) UILabel *label;
- (instancetype)initWithIdent:(NSString *)ident;
- (void)setText:(NSString *)text;
- (void)refresh;
@end

@implementation LMWidget
- (instancetype)initWithIdent:(NSString *)ident {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 80, 26)])) {
        _ident = [ident copy];
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
        self.layer.cornerRadius = 6;
        _label = [UILabel new];
        _label.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold];
        _label.textColor = UIColor.whiteColor;
        _label.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_label];
    }
    return self;
}
- (void)setText:(NSString *)text {
    if ([text isEqualToString:_label.text]) return;
    _label.text = text;
    CGSize s = [_label sizeThatFits:CGSizeMake(400, 40)];
    CGPoint c = self.center;
    self.bounds = CGRectMake(0, 0, ceil(s.width) + 16, ceil(s.height) + 8);
    _label.frame = self.bounds;
    self.center = c;
}
- (void)refresh {}
@end

@interface LMKeystrokesView : LMWidget
@end

@implementation LMKeystrokesView {
    NSDictionary<NSString *, UILabel *> *_cells;
}
- (instancetype)initWithIdent:(NSString *)ident {
    if ((self = [super initWithIdent:ident])) {
        self.label.hidden = YES;
        self.backgroundColor = UIColor.clearColor;
        CGFloat k = 34, g = 3, full = 3 * k + 2 * g, half = (full - g) / 2;
        NSArray *spec = @[
            @[@"W", @(k + g), @0, @(k), @(k)],
            @[@"A", @0, @(k + g), @(k), @(k)],
            @[@"S", @(k + g), @(k + g), @(k), @(k)],
            @[@"D", @(2 * (k + g)), @(k + g), @(k), @(k)],
            @[@"LMB", @0, @(2 * (k + g)), @(half), @28],
            @[@"RMB", @(half + g), @(2 * (k + g)), @(half), @28],
            @[@"SPACE", @0, @(2 * (k + g) + 28 + g), @(full), @18],
        ];
        NSMutableDictionary *cells = [NSMutableDictionary dictionary];
        for (NSArray *c in spec) {
            UILabel *l = [UILabel new];
            l.frame = CGRectMake([c[1] doubleValue], [c[2] doubleValue], [c[3] doubleValue], [c[4] doubleValue]);
            l.text = c[0];
            l.textAlignment = NSTextAlignmentCenter;
            l.font = [UIFont systemFontOfSize:([c[0] length] > 1 ? 11 : 15) weight:UIFontWeightBold];
            l.layer.cornerRadius = 5;
            l.layer.masksToBounds = YES;
            [self addSubview:l];
            cells[c[0]] = l;
        }
        _cells = cells;
        self.bounds = CGRectMake(0, 0, full, 2 * (k + g) + 28 + g + 18);
        [self refresh];
    }
    return self;
}
- (void)setText:(NSString *)text {}
- (void)cell:(NSString *)key on:(BOOL)on {
    UILabel *l = _cells[key];
    l.backgroundColor = on ? [UIColor colorWithWhite:1 alpha:0.9] : [UIColor colorWithWhite:0 alpha:0.45];
    l.textColor = on ? UIColor.blackColor : UIColor.whiteColor;
}
- (void)refresh {
    LMInput *in = [LMInput shared];
    [self cell:@"W" on:in.keyW];
    [self cell:@"A" on:in.keyA];
    [self cell:@"S" on:in.keyS];
    [self cell:@"D" on:in.keyD];
    [self cell:@"LMB" on:in.mouseL];
    [self cell:@"RMB" on:in.mouseR];
    [self cell:@"SPACE" on:in.keySpace];
}
@end

#pragma mark - Crosshair

@interface LMCrosshairView : UIView
@property (nonatomic) NSInteger style, colorIndex;
@property (nonatomic) CGFloat size;
@end

@implementation LMCrosshairView
- (void)drawRect:(CGRect)rect {
    NSArray *colors = @[UIColor.whiteColor, UIColor.systemRedColor, UIColor.systemGreenColor, UIColor.cyanColor, UIColor.systemYellowColor];
    UIColor *c = colors[MAX(0, MIN((NSInteger)colors.count - 1, self.colorIndex))];
    CGPoint o = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGFloat s = self.size > 0 ? self.size : 14, h = s / 2;
    UIBezierPath *p = [UIBezierPath bezierPath];
    BOOL fill = NO;
    switch (self.style) {
        case 1:
            p = [UIBezierPath bezierPathWithArcCenter:o radius:MAX(2, s / 8) startAngle:0 endAngle:2 * M_PI clockwise:YES];
            fill = YES;
            break;
        case 2:
            p = [UIBezierPath bezierPathWithArcCenter:o radius:h startAngle:0 endAngle:2 * M_PI clockwise:YES];
            break;
        case 3: {
            CGFloat g = MAX(3, s / 5);
            [p moveToPoint:CGPointMake(o.x - h, o.y)]; [p addLineToPoint:CGPointMake(o.x - g, o.y)];
            [p moveToPoint:CGPointMake(o.x + g, o.y)]; [p addLineToPoint:CGPointMake(o.x + h, o.y)];
            [p moveToPoint:CGPointMake(o.x, o.y - h)]; [p addLineToPoint:CGPointMake(o.x, o.y - g)];
            [p moveToPoint:CGPointMake(o.x, o.y + g)]; [p addLineToPoint:CGPointMake(o.x, o.y + h)];
            break;
        }
        default:
            [p moveToPoint:CGPointMake(o.x - h, o.y)]; [p addLineToPoint:CGPointMake(o.x + h, o.y)];
            [p moveToPoint:CGPointMake(o.x, o.y - h)]; [p addLineToPoint:CGPointMake(o.x, o.y + h)];
            break;
    }
    UIColor *outline = [UIColor colorWithWhite:0 alpha:0.6];
    if (fill) {
        p.lineWidth = 1.5; [outline setStroke]; [p stroke];
        [c setFill]; [p fill];
    } else {
        p.lineWidth = 4; [outline setStroke]; [p stroke];
        p.lineWidth = 2; [c setStroke]; [p stroke];
    }
}
@end

#pragma mark - Menu

@interface LMMenuView : UIView
@property (nonatomic, copy) void (^onClose)(void);
@property (nonatomic, copy) void (^onEditHUD)(void);
@property (nonatomic, copy) NSArray<NSString *> *(^infoLines)(void);
- (void)reload;
@end

@implementation LMMenuView {
    UISegmentedControl *_profiles, *_tabs;
    UIStackView *_list;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.11 alpha:0.96];
    self.layer.cornerRadius = 16;
    self.layer.borderWidth = 1;
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    self.clipsToBounds = YES;
    __weak LMMenuView *ws = self;

    UILabel *title = LMLabel(@"Lumen Client", 20, UIFontWeightHeavy, UIColor.whiteColor);
    UILabel *sub = LMLabel([NSString stringWithFormat:@"v%@ · Minecraft %@%@", LM_VERSION, LMGameVersion(),
                            LMSafeMode() ? @" · SAFE MODE" : @""],
                           12, UIFontWeightRegular, [UIColor colorWithWhite:1 alpha:0.55]);
    UIStackView *titles = [[UIStackView alloc] initWithArrangedSubviews:@[title, sub]];
    titles.axis = UILayoutConstraintAxisVertical;
    titles.spacing = 2;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"✕" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    close.tintColor = UIColor.whiteColor;
    [close addAction:[UIAction actionWithHandler:^(__kindof UIAction *a) { if (ws.onClose) ws.onClose(); }]
    forControlEvents:UIControlEventTouchUpInside];
    [close.widthAnchor constraintEqualToConstant:44].active = YES;
    [close setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[titles, close]];
    header.alignment = UIStackViewAlignmentCenter;

    _profiles = [[UISegmentedControl alloc] initWithItems:@[@"Profile 1", @"Profile 2", @"Profile 3"]];
    _profiles.selectedSegmentIndex = [LMSettings shared].profile;
    [_profiles addAction:[UIAction actionWithHandler:^(__kindof UIAction *a) {
        LMMenuView *s = ws; if (!s) return;
        [[LMSettings shared] switchToProfile:s->_profiles.selectedSegmentIndex];
        [s reload];
    }] forControlEvents:UIControlEventValueChanged];

    NSMutableArray *tabNames = [[LMModule categories] mutableCopy];
    [tabNames addObject:@"Info"];
    _tabs = [[UISegmentedControl alloc] initWithItems:tabNames];
    _tabs.selectedSegmentIndex = 0;
    [_tabs addAction:[UIAction actionWithHandler:^(__kindof UIAction *a) { [ws reload]; }]
    forControlEvents:UIControlEventValueChanged];

    UIScrollView *scroll = [UIScrollView new];
    scroll.alwaysBounceVertical = YES;
    _list = [UIStackView new];
    _list.axis = UILayoutConstraintAxisVertical;
    _list.spacing = 8;
    _list.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:_list];
    [NSLayoutConstraint activateConstraints:@[
        [_list.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [_list.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [_list.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [_list.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [_list.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
    ]];
    [scroll setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisVertical];
    [scroll setContentCompressionResistancePriority:1 forAxis:UILayoutConstraintAxisVertical];

    UIButton *edit = LMButton(@"Edit HUD", ^{ if (ws.onEditHUD) ws.onEditHUD(); });
    UIButton *safe = LMButton(@"Server-safe", ^{
        for (LMModule *m in [LMModule all])
            if (m.serverRisky) [[LMSettings shared] setEnabled:NO module:m.ident];
        [ws reload];
    });
    UIButton *reset = LMButton(@"Reset profile", ^{ [[LMSettings shared] resetProfile]; [ws reload]; });
    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[edit, safe, reset]];
    buttons.distribution = UIStackViewDistributionFillEqually;
    buttons.spacing = 8;
    [buttons.heightAnchor constraintEqualToConstant:40].active = YES;

    UIStackView *main = [[UIStackView alloc] initWithArrangedSubviews:@[header, _profiles, _tabs, scroll, buttons]];
    main.axis = UILayoutConstraintAxisVertical;
    main.spacing = 10;
    main.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:main];
    [NSLayoutConstraint activateConstraints:@[
        [main.topAnchor constraintEqualToAnchor:self.topAnchor constant:14],
        [main.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-14],
        [main.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
        [main.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
    ]];
    [self reload];
    return self;
}

- (void)reload {
    _profiles.selectedSegmentIndex = [LMSettings shared].profile;
    for (UIView *v in _list.arrangedSubviews) [v removeFromSuperview];
    NSArray *cats = [LMModule categories];
    NSInteger tab = _tabs.selectedSegmentIndex;
    if (tab < 0 || tab >= (NSInteger)cats.count) { [self buildInfo]; return; }
    for (LMModule *m in [LMModule all]) {
        if (![m.category isEqualToString:cats[tab]]) continue;
        [_list addArrangedSubview:[self rowFor:m]];
        if (m.available && [[LMSettings shared] enabled:m.ident]) [self addExtrasFor:m];
    }
}

- (UIView *)rowFor:(LMModule *)m {
    UIView *row = [UIView new];
    row.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    row.layer.cornerRadius = 10;
    UILabel *name = LMLabel(m.needsGameData ? [m.name stringByAppendingString:@" 🔧"] : m.name, 15, UIFontWeightSemibold, UIColor.whiteColor);
    UILabel *detail = LMLabel(m.detail, 12, UIFontWeightRegular, [UIColor colorWithWhite:1 alpha:0.6]);
    UIView *right;
    if (m.available) {
        UISwitch *sw = [UISwitch new];
        sw.on = [[LMSettings shared] enabled:m.ident];
        sw.onTintColor = LMAccent();
        NSString *ident = m.ident;
        __weak LMMenuView *ws = self;
        [sw addAction:[UIAction actionWithHandler:^(__kindof UIAction *a) {
            [[LMSettings shared] setEnabled:((UISwitch *)a.sender).isOn module:ident];
            dispatch_async(dispatch_get_main_queue(), ^{ [ws reload]; });
        }] forControlEvents:UIControlEventValueChanged];
        right = sw;
    } else {
        NSString *why = m.phase > 1 ? [NSString stringWithFormat:@"Phase %ld", (long)m.phase] : @"Needs update";
        UILabel *tag = LMLabel(why, 11, UIFontWeightBold, LMAccent());
        tag.textAlignment = NSTextAlignmentCenter;
        tag.backgroundColor = [LMAccent() colorWithAlphaComponent:0.15];
        tag.layer.cornerRadius = 6;
        tag.layer.masksToBounds = YES;
        [tag.widthAnchor constraintEqualToConstant:84].active = YES;
        [tag.heightAnchor constraintEqualToConstant:24].active = YES;
        right = tag;
    }
    for (UIView *v in @[name, detail, right]) { v.translatesAutoresizingMaskIntoConstraints = NO; [row addSubview:v]; }
    [right setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [right setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [NSLayoutConstraint activateConstraints:@[
        [name.topAnchor constraintEqualToAnchor:row.topAnchor constant:10],
        [name.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [name.trailingAnchor constraintLessThanOrEqualToAnchor:right.leadingAnchor constant:-10],
        [detail.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:2],
        [detail.leadingAnchor constraintEqualToAnchor:name.leadingAnchor],
        [detail.trailingAnchor constraintEqualToAnchor:right.leadingAnchor constant:-10],
        [detail.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-10],
        [right.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [right.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
    ]];
    return row;
}

- (void)addExtrasFor:(LMModule *)m {
    LMSettings *S = [LMSettings shared];
    if ([m.ident isEqualToString:@"crosshair"]) {
        UISegmentedControl *style = [[UISegmentedControl alloc] initWithItems:@[@"Cross", @"Dot", @"Circle", @"Gap"]];
        style.selectedSegmentIndex = [S integerForKey:@"crosshair.style" fallback:0];
        [style addAction:[UIAction actionWithHandler:^(__kindof UIAction *a) {
            [S setObject:@(((UISegmentedControl *)a.sender).selectedSegmentIndex) forKey:@"crosshair.style"];
        }] forControlEvents:UIControlEventValueChanged];

        UISegmentedControl *color = [[UISegmentedControl alloc] initWithItems:@[@"White", @"Red", @"Green", @"Cyan", @"Yellow"]];
        color.selectedSegmentIndex = [S integerForKey:@"crosshair.color" fallback:0];
        [color addAction:[UIAction actionWithHandler:^(__kindof UIAction *a) {
            [S setObject:@(((UISegmentedControl *)a.sender).selectedSegmentIndex) forKey:@"crosshair.color"];
        }] forControlEvents:UIControlEventValueChanged];

        UISlider *size = [UISlider new];
        size.minimumValue = 6; size.maximumValue = 40;
        size.value = [S doubleForKey:@"crosshair.size" fallback:14];
        size.minimumTrackTintColor = LMAccent();
        [size addAction:[UIAction actionWithHandler:^(__kindof UIAction *a) {
            [S setObject:@(((UISlider *)a.sender).value) forKey:@"crosshair.size"];
        }] forControlEvents:UIControlEventValueChanged];

        [_list addArrangedSubview:style];
        [_list addArrangedSubview:color];
        [_list addArrangedSubview:size];
    } else if ([m.ident isEqualToString:@"fpsunlock"]) {
        NSString *t = [NSString stringWithFormat:@"Target: %ld FPS (your screen's max).%@", (long)(LMScreenMaxFPSCached ?: 60),
                       NSProcessInfo.processInfo.lowPowerModeEnabled ? @" Low Power Mode is on - it caps at 60." : @""];
        [_list addArrangedSubview:LMLabel(t, 12, UIFontWeightRegular, [UIColor colorWithWhite:1 alpha:0.7])];
    } else if ([m.ident isEqualToString:@"keystrokes"] || [m.ident isEqualToString:@"cps"]) {
        [_list addArrangedSubview:LMLabel(@"Touch: the bottom-left third of the screen counts as movement, other taps count as clicks.",
                                          12, UIFontWeightRegular, [UIColor colorWithWhite:1 alpha:0.7])];
    }
}

- (void)buildInfo {
    NSArray *lines = self.infoLines ? self.infoLines() : @[];
    for (NSString *line in lines) {
        UILabel *l = LMLabel(line, 13, UIFontWeightMedium, UIColor.whiteColor);
        [_list addArrangedSubview:l];
    }
    __weak LMMenuView *ws = self;
    [_list addArrangedSubview:LMButton(@"Refresh", ^{ [ws reload]; })];
}
@end

#pragma mark - Controller

@implementation LMUI {
    UIWindow *_window;
    UIView *_root;
    UIButton *_fab;
    LMCrosshairView *_crosshair;
    NSMutableDictionary<NSString *, LMWidget *> *_widgets;
    LMMenuView *_menu;
    UIView *_editBar;
    BOOL _editing;
    NSTimer *_timer;
    NSUInteger _ticks;
    CFTimeInterval _fpsT;
    uint64_t _fpsFrames;
    double _fps;
    BOOL _swRunning;
    CFTimeInterval _swStart, _swAccum;
    CGPoint _dragRaw;
}

+ (instancetype)shared {
    static LMUI *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [LMUI new]; });
    return s;
}

- (UIWindow *)overlayWindow { return _window; }
- (double)currentFPS { return _fps; }

- (void)start {
    if (_window) return;
    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if (![s isKindOfClass:UIWindowScene.class]) continue;
        if (!scene || s.activationState == UISceneActivationStateForegroundActive) scene = (UIWindowScene *)s;
    }
    if (!scene) return;   // try again on the next activation

    LMScreenMaxFPSCached = scene.screen.maximumFramesPerSecond;
    LMPassWindow *w = [[LMPassWindow alloc] initWithWindowScene:scene];
    w.windowLevel = UIWindowLevelStatusBar + 100;
    w.backgroundColor = UIColor.clearColor;
    w.rootViewController = [LMRootVC new];
    w.hidden = NO;
    _window = w;
    _root = w.rootViewController.view;

    _crosshair = [LMCrosshairView new];
    _crosshair.opaque = NO;
    _crosshair.backgroundColor = UIColor.clearColor;
    _crosshair.userInteractionEnabled = NO;
    _crosshair.contentMode = UIViewContentModeRedraw;
    [_root addSubview:_crosshair];

    [self buildWidgets];
    [self buildFab];
    [self setEditing:NO];

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(settingsChanged)
                                               name:LMSettingsChangedNotification object:nil];
    [self settingsChanged];

    _fpsT = CACurrentMediaTime();
    _fpsFrames = atomic_load(&LMFrameCounter);
    __weak LMUI *ws = self;
    _timer = [NSTimer timerWithTimeInterval:1.0 / 200 repeats:YES block:^(NSTimer *t) { [ws tick]; }];
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];

    [self toast:LMSafeMode() ? @"Lumen: safe mode - last launch crashed, hooks are off this time"
                             : [NSString stringWithFormat:@"Lumen Client %@ loaded · Minecraft %@", LM_VERSION, LMGameVersion()]];
}

#pragma mark Building

- (void)buildFab {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = CGRectMake(0, 0, 46, 46);
    [b setTitle:@"L" forState:UIControlStateNormal];
    [b setTitleColor:LMAccent() forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightHeavy];
    b.backgroundColor = [UIColor colorWithRed:0.10 green:0.11 blue:0.16 alpha:0.85];
    b.layer.cornerRadius = 23;
    b.layer.borderWidth = 2;
    b.layer.borderColor = LMAccent().CGColor;
    __weak LMUI *ws = self;
    [b addAction:[UIAction actionWithHandler:^(__kindof UIAction *a) { [ws toggleMenu]; }]
    forControlEvents:UIControlEventTouchUpInside];
    [b addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(fabPan:)]];
    [_root addSubview:b];
    _fab = b;
}

- (void)buildWidgets {
    _widgets = [NSMutableDictionary dictionary];
    for (LMModule *m in [LMModule all]) {
        if (!m.hasWidget || m.phase > 1) continue;
        LMWidget *w = [m.ident isEqualToString:@"keystrokes"] ? [[LMKeystrokesView alloc] initWithIdent:m.ident]
                                                               : [[LMWidget alloc] initWithIdent:m.ident];
        w.hidden = YES;
        [w setText:@"--"];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(widgetPan:)];
        UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(widgetPinch:)];
        UITapGestureRecognizer *dbl = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(widgetResetScale:)];
        dbl.numberOfTapsRequired = 2;
        for (UIGestureRecognizer *g in @[pan, pinch, dbl]) { g.name = @"edit"; [w addGestureRecognizer:g]; }

        if ([m.ident isEqualToString:@"stopwatch"]) {
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(swTap)];
            UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(swHold:)];
            tap.name = hold.name = @"use";
            [w addGestureRecognizer:tap];
            [w addGestureRecognizer:hold];
        }
        [_root addSubview:w];
        _widgets[m.ident] = w;
    }
}

#pragma mark Layout

- (CGPoint)defaultPosFor:(NSString *)ident {
    NSDictionary *d = @{ @"fps": @[@0.08, @0.07], @"cps": @[@0.08, @0.12], @"clock": @[@0.92, @0.07],
                         @"session": @[@0.92, @0.12], @"stopwatch": @[@0.92, @0.17], @"keystrokes": @[@0.10, @0.33],
                         @"button": @[@0.035, @0.5] };
    NSArray *a = d[ident] ?: @[@0.5, @0.3];
    return CGPointMake([a[0] doubleValue], [a[1] doubleValue]);
}

- (CGPoint)savedPosFor:(NSString *)ident {
    id p = [[LMSettings shared] objectForKey:[@"pos." stringByAppendingString:ident]];
    if ([p isKindOfClass:NSArray.class] && [p count] == 2) return CGPointMake([p[0] doubleValue], [p[1] doubleValue]);
    return [self defaultPosFor:ident];
}

- (void)savePos:(CGPoint)c forIdent:(NSString *)ident {
    CGSize sz = _root.bounds.size;
    if (sz.width < 1 || sz.height < 1) return;
    [[LMSettings shared] setObjectQuietly:@[@(c.x / sz.width), @(c.y / sz.height)] forKey:[@"pos." stringByAppendingString:ident]];
}

- (CGPoint)clamp:(CGPoint)c halfSize:(CGSize)h {
    CGSize sz = _root.bounds.size;
    c.x = MAX(h.width + 4, MIN(sz.width - h.width - 4, c.x));
    c.y = MAX(h.height + 4, MIN(sz.height - h.height - 4, c.y));
    return c;
}

- (void)layoutOverlay {
    CGSize sz = _root.bounds.size;
    if (sz.width < 1) return;
    _crosshair.frame = _root.bounds;
    [_crosshair setNeedsDisplay];
    for (LMWidget *w in _widgets.allValues) {
        double s = [[LMSettings shared] doubleForKey:[@"scale." stringByAppendingString:w.ident] fallback:1];
        w.transform = CGAffineTransformMakeScale(s, s);
        CGPoint n = [self savedPosFor:w.ident];
        w.center = [self clamp:CGPointMake(n.x * sz.width, n.y * sz.height)
                      halfSize:CGSizeMake(w.frame.size.width / 2, w.frame.size.height / 2)];
    }
    CGPoint b = [self savedPosFor:@"button"];
    _fab.center = [self clamp:CGPointMake(b.x * sz.width, b.y * sz.height) halfSize:CGSizeMake(23, 23)];
    if (_menu) _menu.frame = [self menuFrame];
    if (_editBar) [self placeEditBar];
}

- (CGRect)menuFrame {
    CGSize sz = _root.bounds.size;
    UIEdgeInsets sa = _root.safeAreaInsets;
    CGFloat w = MIN(480, sz.width - 40), h = MIN(600, sz.height - 40 - sa.top - sa.bottom);
    return CGRectMake((sz.width - w) / 2, sa.top + (sz.height - sa.top - sa.bottom - h) / 2, w, h);
}

#pragma mark Settings

- (void)settingsChanged {
    LMSettings *S = [LMSettings shared];
    for (NSString *ident in _widgets) _widgets[ident].hidden = ![S enabled:ident];
    _crosshair.hidden = ![S enabled:@"crosshair"];
    _crosshair.style = [S integerForKey:@"crosshair.style" fallback:0];
    _crosshair.colorIndex = [S integerForKey:@"crosshair.color" fallback:0];
    _crosshair.size = [S doubleForKey:@"crosshair.size" fallback:14];
    [_crosshair setNeedsDisplay];
    [self layoutOverlay];
    if (!LMSafeMode()) LMApplyFrameUnlock();
    [self refreshWidgets];
}

#pragma mark Tick

- (void)tick {
    [[LMInput shared] poll];
    if (++_ticks % 6) return;   // widgets refresh ~33x per second
    CFTimeInterval now = CACurrentMediaTime();
    if (now - _fpsT >= 0.5) {
        uint64_t f = atomic_load(&LMFrameCounter);
        _fps = (double)(f - _fpsFrames) / (now - _fpsT);
        _fpsFrames = f;
        _fpsT = now;
    }
    [self refreshWidgets];
}

- (void)refreshWidgets {
    static NSDateFormatter *clockFmt;
    if (!clockFmt) {
        clockFmt = [NSDateFormatter new];
        clockFmt.dateStyle = NSDateFormatterNoStyle;
        clockFmt.timeStyle = NSDateFormatterShortStyle;
    }
    LMInput *in = [LMInput shared];
    CFTimeInterval now = CACurrentMediaTime();
    for (NSString *ident in _widgets) {
        LMWidget *w = _widgets[ident];
        if (w.hidden) continue;
        if ([ident isEqualToString:@"fps"]) {
            [w setText:atomic_load(&LMFrameCounter) ? [NSString stringWithFormat:@"%.0f FPS", _fps] : @"-- FPS"];
        } else if ([ident isEqualToString:@"cps"]) {
            [w setText:in.mouseMode ? [NSString stringWithFormat:@"%ld | %ld CPS", (long)in.cpsLeft, (long)in.cpsRight]
                                    : [NSString stringWithFormat:@"%ld CPS", (long)(in.cpsLeft + in.cpsRight)]];
        } else if ([ident isEqualToString:@"clock"]) {
            [w setText:[clockFmt stringFromDate:[NSDate date]]];
        } else if ([ident isEqualToString:@"session"]) {
            [w setText:[@"Session " stringByAppendingString:LMDuration(now - LMLaunchTime(), NO)]];
        } else if ([ident isEqualToString:@"stopwatch"]) {
            double t = _swAccum + (_swRunning ? now - _swStart : 0);
            [w setText:[NSString stringWithFormat:@"%@ %@", _swRunning ? @"▶" : @"⏸", LMDuration(t, YES)]];
        } else {
            [w refresh];
        }
    }
}

#pragma mark Menu

- (void)toggleMenu {
    if (_menu) { [self closeMenu]; return; }
    LMMenuView *m = [[LMMenuView alloc] initWithFrame:[self menuFrame]];
    __weak LMUI *ws = self;
    m.onClose = ^{ [ws closeMenu]; };
    m.onEditHUD = ^{ [ws closeMenu]; [ws setEditing:YES]; };
    m.infoLines = ^NSArray<NSString *> *{ return [ws selfTestLines]; };
    m.alpha = 0;
    [_root addSubview:m];
    _menu = m;
    [UIView animateWithDuration:0.15 animations:^{ m.alpha = 1; }];
}

- (void)closeMenu {
    UIView *m = _menu;
    _menu = nil;
    [UIView animateWithDuration:0.12 animations:^{ m.alpha = 0; } completion:^(BOOL f) { [m removeFromSuperview]; }];
}

- (NSArray<NSString *> *)selfTestLines {
    NSMutableArray *a = [NSMutableArray array];
    uint64_t frames = atomic_load(&LMFrameCounter);
    LMInput *in = [LMInput shared];
    [a addObject:[NSString stringWithFormat:@"✅ Client injected - Lumen v%@", LM_VERSION]];
    [a addObject:[NSString stringWithFormat:@"ℹ️ Minecraft %@ (%@)", LMGameVersion(), NSBundle.mainBundle.bundleIdentifier ?: @"?"]];
    [a addObject:LMSafeMode() ? @"⚠️ Safe mode: last launch crashed during startup, hooks skipped this launch"
                              : [NSString stringWithFormat:@"✅ Hooks installed: %ld", (long)LMHookCount]];
    [a addObject:frames ? [NSString stringWithFormat:@"✅ Frame hook: %llu frames seen, %.0f FPS now", (unsigned long long)frames, _fps]
                        : @"❌ Frame hook: no frames seen yet (open a world, then Refresh)"];
    [a addObject:[NSString stringWithFormat:@"ℹ️ Screen max %ld Hz · display links %lu%@", (long)LMScreenMaxFPSCached,
                  (unsigned long)LMDisplayLinkCount(),
                  NSProcessInfo.processInfo.lowPowerModeEnabled ? @" · ⚠️ Low Power Mode caps at 60" : @""]];
    [a addObject:[NSString stringWithFormat:@"ℹ️ Input: %@ · keyboard %@ · mouse %@ · controller %@ · touches %llu",
                  in.activeSource, GCKeyboard.coalescedKeyboard ? @"yes" : @"no", GCMouse.current ? @"yes" : @"no",
                  GCController.current ? @"yes" : @"no", (unsigned long long)in.touchesSeen]];
    NSInteger ready = 0, later = 0;
    for (LMModule *m in [LMModule all]) { if (m.available) ready++; else if (m.phase > 1) later++; }
    [a addObject:[NSString stringWithFormat:@"✅ %ld modules ready on this version", (long)ready]];
    if (!LMGameVersionSupported()) [a addObject:@"⚠️ Game-data modules (🔧) stay off until this Minecraft version is mapped"];
    [a addObject:[NSString stringWithFormat:@"🕒 %ld modules arrive in later phases", (long)later]];
    return a;
}

#pragma mark Edit HUD

- (void)setEditing:(BOOL)on {
    _editing = on;
    BOOL anyVisible = NO;
    for (LMWidget *w in _widgets.allValues) {
        if (!w.hidden) anyVisible = YES;
        w.userInteractionEnabled = on || [w.ident isEqualToString:@"stopwatch"];
        for (UIGestureRecognizer *g in w.gestureRecognizers)
            g.enabled = [g.name isEqualToString:@"edit"] ? on : !on;
        w.layer.borderWidth = on ? 1.5 : 0;
        w.layer.borderColor = LMAccent().CGColor;
    }
    _fab.hidden = on;
    [_editBar removeFromSuperview];
    _editBar = nil;
    if (!on) return;

    UIView *bar = [UIView new];
    bar.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    bar.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.11 alpha:0.94];
    bar.layer.cornerRadius = 12;
    UILabel *hint = LMLabel(anyVisible ? @"Drag to move · Pinch to resize · Double-tap resets size"
                                       : @"Turn on a HUD module first (menu → HUD)",
                            13, UIFontWeightMedium, UIColor.whiteColor);
    __weak LMUI *ws = self;
    UIButton *done = LMButton(@"Done", ^{ [ws setEditing:NO]; });
    [done setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[hint, done]];
    row.spacing = 12;
    row.alignment = UIStackViewAlignmentCenter;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:bar.topAnchor constant:8],
        [row.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-8],
        [row.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:14],
        [row.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-8],
    ]];
    [_root addSubview:bar];
    _editBar = bar;
    [self placeEditBar];
}

- (void)placeEditBar {
    CGSize sz = _root.bounds.size;
    CGFloat w = MIN(560, sz.width - 40);
    _editBar.frame = CGRectMake((sz.width - w) / 2, _root.safeAreaInsets.top + 12, w, 54);
}

- (void)fabPan:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:_root];
    _fab.center = [self clamp:CGPointMake(_fab.center.x + t.x, _fab.center.y + t.y) halfSize:CGSizeMake(23, 23)];
    [g setTranslation:CGPointZero inView:_root];
    if (g.state == UIGestureRecognizerStateEnded) [self savePos:_fab.center forIdent:@"button"];
}

- (void)widgetPan:(UIPanGestureRecognizer *)g {
    LMWidget *w = (LMWidget *)g.view;
    if (g.state == UIGestureRecognizerStateBegan) _dragRaw = w.center;
    CGPoint t = [g translationInView:_root];
    [g setTranslation:CGPointZero inView:_root];
    _dragRaw = CGPointMake(_dragRaw.x + t.x, _dragRaw.y + t.y);

    // Snap to screen edges and the vertical centre line.
    CGSize sz = _root.bounds.size, h = CGSizeMake(w.frame.size.width / 2, w.frame.size.height / 2);
    CGPoint c = _dragRaw;
    if (c.x - h.width < 14) c.x = h.width + 4;
    if (c.x + h.width > sz.width - 14) c.x = sz.width - h.width - 4;
    if (c.y - h.height < 14) c.y = h.height + 4;
    if (c.y + h.height > sz.height - 14) c.y = sz.height - h.height - 4;
    if (fabs(c.x - sz.width / 2) < 8) c.x = sz.width / 2;
    w.center = c;
    if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled)
        [self savePos:w.center forIdent:w.ident];
}

- (void)widgetPinch:(UIPinchGestureRecognizer *)g {
    LMWidget *w = (LMWidget *)g.view;
    CGFloat s = MAX(0.5, MIN(2.5, w.transform.a * g.scale));
    g.scale = 1;
    w.transform = CGAffineTransformMakeScale(s, s);
    if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled)
        [[LMSettings shared] setObjectQuietly:@(s) forKey:[@"scale." stringByAppendingString:w.ident]];
}

- (void)widgetResetScale:(UITapGestureRecognizer *)g {
    LMWidget *w = (LMWidget *)g.view;
    w.transform = CGAffineTransformIdentity;
    [[LMSettings shared] setObjectQuietly:@1 forKey:[@"scale." stringByAppendingString:w.ident]];
}

#pragma mark Stopwatch

- (void)swTap {
    CFTimeInterval now = CACurrentMediaTime();
    if (_swRunning) { _swAccum += now - _swStart; _swRunning = NO; }
    else { _swStart = now; _swRunning = YES; }
}

- (void)swHold:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) { _swRunning = NO; _swAccum = 0; }
}

#pragma mark Toast

- (void)toast:(NSString *)text {
    if (!_root) return;
    UILabel *l = LMLabel(text, 14, UIFontWeightSemibold, UIColor.whiteColor);
    l.textAlignment = NSTextAlignmentCenter;
    l.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.11 alpha:0.92];
    l.layer.cornerRadius = 10;
    l.layer.masksToBounds = YES;
    CGSize s = [l sizeThatFits:CGSizeMake(_root.bounds.size.width - 60, 200)];
    l.frame = CGRectMake(0, 0, s.width + 28, s.height + 16);
    l.center = CGPointMake(_root.bounds.size.width / 2, _root.safeAreaInsets.top + 40);
    l.userInteractionEnabled = NO;
    [_root addSubview:l];
    [UIView animateWithDuration:0.4 delay:3.0 options:0 animations:^{ l.alpha = 0; }
                     completion:^(BOOL f) { [l removeFromSuperview]; }];
}

@end
