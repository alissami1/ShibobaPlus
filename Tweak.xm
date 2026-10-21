// ShibobaPlus — Tweak.xm
// Injected next to Beegram.dylib in Instagram 444.0.0
// Uses Logos "internal" generator => no CydiaSubstrate dependency (works for sideloaded IPA).
%config(generator=internal);

#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - Prefs

#define SBP_SUITE @"com.shiboba.plus"

static NSUserDefaults *SBD(void) {
    static NSUserDefaults *d; static dispatch_once_t t;
    dispatch_once(&t, ^{ d = [[NSUserDefaults alloc] initWithSuiteName:SBP_SUITE]; });
    return d;
}
static BOOL SBBool(NSString *k, BOOL d) { id v = [SBD() objectForKey:k]; return v ? [v boolValue] : d; }
static NSString *SBStr(NSString *k, NSString *d) { NSString *v = [SBD() stringForKey:k]; return v.length ? v : d; }
static double SBNum(NSString *k, double d) { id v = [SBD() objectForKey:k]; return v ? [v doubleValue] : d; }

static UIColor *SBColor(NSString *hex, UIColor *fb) {
    NSString *h = [[hex stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]
                   stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (h.length != 6) return fb;
    unsigned v = 0;
    if (![[NSScanner scannerWithString:h] scanHexInt:&v]) return fb;
    return [UIColor colorWithRed:((v >> 16) & 255) / 255.0 green:((v >> 8) & 255) / 255.0 blue:(v & 255) / 255.0 alpha:1];
}

#pragma mark - UI helpers

static UIWindowScene *SBScene(void) {
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
        if ([s isKindOfClass:UIWindowScene.class] && s.activationState == UISceneActivationStateForegroundActive)
            return (UIWindowScene *)s;
    return nil;
}
static UIWindow *SBKeyWindow(void) {
    for (UIWindow *w in SBScene().windows) if (w.isKeyWindow) return w;
    return nil;
}
static UIViewController *SBTopVC(void) {
    UIViewController *vc = SBKeyWindow().rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

static void SBToast(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = SBKeyWindow(); if (!w) return;
        UILabel *l = [UILabel new];
        l.text = msg; l.font = [UIFont boldSystemFontOfSize:14]; l.textColor = UIColor.whiteColor;
        l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.88];
        l.layer.cornerRadius = 14; l.clipsToBounds = YES; l.textAlignment = NSTextAlignmentCenter; l.numberOfLines = 2;
        CGFloat maxW = w.bounds.size.width - 40;
        CGSize s = [l sizeThatFits:CGSizeMake(maxW - 24, CGFLOAT_MAX)];
        CGFloat bw = MIN(s.width + 24, maxW);
        l.frame = CGRectMake((w.bounds.size.width - bw) / 2, w.safeAreaInsets.top + 8, bw, s.height + 16);
        l.alpha = 0; [w addSubview:l];
        [UIView animateWithDuration:.3 animations:^{ l.alpha = 1; } completion:^(BOOL f) {
            [UIView animateWithDuration:.3 delay:3 options:0 animations:^{ l.alpha = 0; }
                             completion:^(BOOL f2) { [l removeFromSuperview]; }];
        }];
    });
}

#pragma mark - 1) Welcome message (neon, transparent)

static UIWindow *sWelcomeWin;

static void SBShowWelcome(BOOL force) {
    if (!force && !SBBool(@"welcome_on", NO)) return;
    UIWindowScene *sc = SBScene(); if (!sc) return;
    NSString *text = SBStr(@"welcome_text", @"أهلاً بك في شيبوبة بلس");
    UIColor *c = SBColor(SBStr(@"welcome_color", @"#00F6FF"), [UIColor cyanColor]);
    CGFloat size = SBNum(@"welcome_size", 28);
    double dur = SBNum(@"welcome_dur", 2.5);

    UIWindow *w = [[UIWindow alloc] initWithWindowScene:sc];
    w.windowLevel = UIWindowLevelAlert + 50;
    w.backgroundColor = UIColor.clearColor;
    w.userInteractionEnabled = NO;
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.clearColor;
    w.rootViewController = vc;

    UILabel *l = [[UILabel alloc] initWithFrame:CGRectInset(w.bounds, 20, 0)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    l.text = text; l.numberOfLines = 0; l.textAlignment = NSTextAlignmentCenter;
    l.font = [UIFont systemFontOfSize:size weight:UIFontWeightHeavy];
    l.textColor = c; l.backgroundColor = UIColor.clearColor;
    l.layer.masksToBounds = NO;
    l.layer.shadowColor = c.CGColor; l.layer.shadowOffset = CGSizeZero;
    l.layer.shadowRadius = 14; l.layer.shadowOpacity = 1;
    l.alpha = 0;
    [vc.view addSubview:l];
    // second, softer glow layer for the neon look
    UILabel *g = [[UILabel alloc] initWithFrame:l.frame];
    g.autoresizingMask = l.autoresizingMask; g.text = text; g.numberOfLines = 0;
    g.textAlignment = NSTextAlignmentCenter; g.font = l.font; g.textColor = c; g.backgroundColor = UIColor.clearColor;
    g.layer.shadowColor = c.CGColor; g.layer.shadowOffset = CGSizeZero; g.layer.shadowRadius = 34; g.layer.shadowOpacity = 0.9;
    g.alpha = 0; [vc.view insertSubview:g belowSubview:l];

    sWelcomeWin = w; w.hidden = NO;
    [UIView animateWithDuration:.6 animations:^{ l.alpha = 1; g.alpha = 0.8; } completion:^(BOOL f) {
        [UIView animateWithDuration:.6 delay:dur options:0 animations:^{ l.alpha = 0; g.alpha = 0; }
                         completion:^(BOOL f2) { w.hidden = YES; if (sWelcomeWin == w) sWelcomeWin = nil; }];
    }];
}

#pragma mark - Networking (reuses Beegram's session extraction, cookie fallback)

static id SBInvoke(Class U, NSString *sel, id arg) {
    if (!U) return nil;
    SEL s = NSSelectorFromString(sel);
    id target = nil;
    if ([U respondsToSelector:s]) target = U;
    else if ([U instancesRespondToSelector:s]) target = [U new];
    if (!target) return nil;
    return arg ? ((id (*)(id, SEL, id))objc_msgSend)(target, s, arg)
               : ((id (*)(id, SEL))objc_msgSend)(target, s);
}

static NSString *SBUidFromAuth(NSString *auth) {
    NSRange r = [auth rangeOfString:@"IGT:2:"];
    if (r.location == NSNotFound) return nil;
    NSData *d = [[NSData alloc] initWithBase64EncodedString:[auth substringFromIndex:NSMaxRange(r)]
                                                    options:NSDataBase64DecodingIgnoreUnknownCharacters];
    id j = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
    return [j isKindOfClass:NSDictionary.class] && j[@"ds_user_id"] ? [NSString stringWithFormat:@"%@", j[@"ds_user_id"]] : nil;
}

static void SBFinishAuth(NSString *auth, NSString *csrf, NSString *ua, NSString *uid,
                         void (^cb)(NSDictionary *, NSString *)) {
    NSMutableDictionary *h = [@{
        @"X-IG-App-ID": @"936619743392459",
        @"Accept-Language": @"en-US, en;q=0.9",
        @"User-Agent": ua.length ? ua : @"Instagram 444.0.0.0.0 (iPhone14,2; iOS 16_7_12; en_US; en-US; scale=3.00; 1170x2532; 1047335181)"
    } mutableCopy];
    if (auth.length) h[@"Authorization"] = auth;
    if (csrf.length) h[@"X-CSRFToken"] = csrf;
    if (!uid.length) uid = SBUidFromAuth(auth);
    if (uid.length) h[@"IG-U-DS-USER-ID"] = uid;

    if (!auth.length) { // cookie fallback
        NSString *sid = nil;
        for (NSHTTPCookie *c in [NSHTTPCookieStorage.sharedHTTPCookieStorage cookies]) {
            if (![c.domain containsString:@"instagram.com"]) continue;
            if ([c.name isEqualToString:@"sessionid"]) sid = c.value;
            if ([c.name isEqualToString:@"ds_user_id"] && !uid.length) uid = c.value;
            if ([c.name isEqualToString:@"csrftoken"]) h[@"X-CSRFToken"] = c.value;
        }
        if (sid.length) h[@"Cookie"] = [NSString stringWithFormat:@"sessionid=%@", sid];
        else { cb(nil, nil); return; }
    }
    cb(h, uid);
}

static void SBAuth(void (^cb)(NSDictionary *h, NSString *uid)) {
    @try {
        Class U = NSClassFromString(@"BeegramSessionUtils");
        SEL sSess = NSSelectorFromString(@"extractUserSessionWithCompletion:");
        if (U && ([U respondsToSelector:sSess] || [U instancesRespondToSelector:sSess])) {
            __block BOOL done = NO;
            void (^got)(id) = ^(id session) {
                if (done) return; done = YES;
                @try {
                    NSString *auth = SBInvoke(U, @"extractAuthorizationHeaderFromSession:", session);
                    NSString *csrf = SBInvoke(U, @"extractCSRFTokenFromSession:", session);
                    NSString *ua = SBInvoke(U, @"extractUserAgent", nil);
                    SBFinishAuth(auth, csrf, ua, nil, cb);
                } @catch (__unused id e) { SBFinishAuth(nil, nil, nil, nil, cb); }
            };
            id target = [U respondsToSelector:sSess] ? (id)U : [U new];
            ((void (*)(id, SEL, id))objc_msgSend)(target, sSess, got);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                if (!done) { done = YES; SBFinishAuth(nil, nil, nil, nil, cb); }
            });
            return;
        }
    } @catch (__unused id e) {}
    SBFinishAuth(nil, nil, nil, nil, cb);
}

static void SBGet(NSString *path, void (^cb)(NSDictionary *json)) {
    SBAuth(^(NSDictionary *h, NSString *uid) {
        if (!h) { cb(nil); return; }
        NSURL *u = [NSURL URLWithString:[@"https://i.instagram.com/api/v1" stringByAppendingString:path]];
        NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:u];
        for (NSString *k in h) [r setValue:h[k] forHTTPHeaderField:k];
        [[NSURLSession.sharedSession dataTaskWithRequest:r completionHandler:^(NSData *d, NSURLResponse *resp, NSError *e) {
            id j = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
            cb([j isKindOfClass:NSDictionary.class] ? j : nil);
        }] resume];
    });
}

#pragma mark - Log + notify

static void SBLog(NSString *type, NSString *user) {
    NSMutableArray *a = [([SBD() arrayForKey:@"log"] ?: @[]) mutableCopy];
    [a insertObject:@{@"t": type, @"u": user ?: @"", @"ts": @([NSDate date].timeIntervalSince1970)} atIndex:0];
    while (a.count > 200) [a removeLastObject];
    [SBD() setObject:a forKey:@"log"];
}
static void SBNotify(NSString *body) {
    UNMutableNotificationContent *c = [UNMutableNotificationContent new];
    c.title = @"شيبوبة بلس"; c.body = body; c.sound = UNNotificationSound.defaultSound;
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:
        [UNNotificationRequest requestWithIdentifier:NSUUID.UUID.UUIDString content:c trigger:nil] withCompletionHandler:nil];
    SBToast(body);
}

#pragma mark - 6) Story viewers notifier

static BOOL sChecking = NO;

static void SBCheckStoryViewers(BOOL force) {
    if (!force && !SBBool(@"story_on", NO)) return;
    if (sChecking) return;
    sChecking = YES;
    SBAuth(^(NSDictionary *h, NSString *uid) {
        if (!uid.length) { sChecking = NO; if (force) SBToast(@"ما كدرت أجيب الجلسة"); return; }
        SBGet([NSString stringWithFormat:@"/feed/reels_media/?reel_ids=%@", uid], ^(NSDictionary *j) {
            NSDictionary *reel = j[@"reels"][uid];
            NSArray *items = reel[@"items"];
            if (!items.count) { sChecking = NO; if (force) SBToast(@"ما عندك ستوري فعال"); return; }
            BOOL baseline = ![SBD() boolForKey:@"story_base"];
            NSMutableDictionary *seen = [([SBD() dictionaryForKey:@"story_seen"] ?: @{}) mutableCopy];
            dispatch_group_t g = dispatch_group_create();
            __block NSInteger fresh = 0;
            for (NSDictionary *it in items) {
                NSString *pk = [NSString stringWithFormat:@"%@", it[@"pk"] ?: it[@"id"]];
                if ([pk containsString:@"_"]) pk = [pk componentsSeparatedByString:@"_"].firstObject;
                dispatch_group_enter(g);
                SBGet([NSString stringWithFormat:@"/media/%@/list_reel_media_viewer/", pk], ^(NSDictionary *vj) {
                    NSArray *users = vj[@"users"] ?: vj[@"viewers"] ?: @[];
                    NSMutableArray *old = [([seen[pk] isKindOfClass:NSArray.class] ? seen[pk] : @[]) mutableCopy];
                    for (NSDictionary *e in users) {
                        NSDictionary *u = e[@"user"] ?: e;
                        NSString *vpk = [NSString stringWithFormat:@"%@", u[@"pk"] ?: u[@"id"]];
                        if ([old containsObject:vpk]) continue;
                        [old addObject:vpk];
                        if (!baseline) {
                            fresh++;
                            NSString *name = u[@"username"] ?: vpk;
                            SBLog(@"story", name);
                            dispatch_async(dispatch_get_main_queue(), ^{
                                SBNotify([NSString stringWithFormat:@"@%@ شاف الستوري مالتك 👁", name]);
                            });
                        }
                    }
                    @synchronized (seen) { seen[pk] = old; }
                    dispatch_group_leave(g);
                });
            }
            dispatch_group_notify(g, dispatch_get_main_queue(), ^{
                [SBD() setObject:seen forKey:@"story_seen"];
                [SBD() setBool:YES forKey:@"story_base"];
                sChecking = NO;
                if (force && fresh == 0) SBToast(baseline ? @"تم حفظ المشاهدات الحالية، الجديد راح ينبلغ عنه" : @"ماكو مشاهدات جديدة");
            });
        });
    });
}

#pragma mark - 3) Reels clean mode

@interface IGSundialFeedViewController : UIViewController @end

static BOOL sClean = NO;
static NSTimer *sReelTimer;
static char kHid;

static BOOL SBIsHUD(UIView *v) {
    NSString *n = [NSStringFromClass(v.class) componentsSeparatedByString:@"."].lastObject;
    if ([n isEqualToString:@"IGSundialViewerVerticalUFI"] ||
        [n isEqualToString:@"IGSundialViewerControlsOverlayView"] ||
        [n isEqualToString:@"IGSundialViewerAttributionView"] ||
        [n isEqualToString:@"IGSundialViewerAudioAttributionView"] ||
        [n isEqualToString:@"IGSundialViewerCoauthorUserAttributionView"]) return YES;
    return [n hasPrefix:@"IGSundialViewerBottomBar"] && [n hasSuffix:@"ContentView"];
}
static void SBApplyClean(UIView *v) {
    if (SBIsHUD(v)) {
        if (sClean) {
            if (!v.hidden) { v.hidden = YES; objc_setAssociatedObject(v, &kHid, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        } else if ([objc_getAssociatedObject(v, &kHid) boolValue]) {
            v.hidden = NO; objc_setAssociatedObject(v, &kHid, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    for (UIView *s in v.subviews) SBApplyClean(s);
}

#pragma mark - Helper (gesture / button targets)

@interface SBPHelper : NSObject
+ (void)openGesture:(UILongPressGestureRecognizer *)g;
+ (void)toggleClean:(UIButton *)b;
@end

static void SBOpenSettings(void);

@implementation SBPHelper
+ (void)openGesture:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) SBOpenSettings();
}
+ (void)toggleClean:(UIButton *)b {
    sClean = !sClean;
    [b setImage:[UIImage systemImageNamed:sClean ? @"eye.slash" : @"eye"] forState:UIControlStateNormal];
    if (b.superview) SBApplyClean(b.superview);
}
@end

%hook IGSundialFeedViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!SBBool(@"reels_btn", NO)) return;
    UIButton *btn = (UIButton *)[self.view viewWithTag:0x5B0B];
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 0x5B0B;
        btn.frame = CGRectMake(self.view.bounds.size.width - 58, self.view.safeAreaInsets.top + 90, 44, 44);
        btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        btn.layer.cornerRadius = 22;
        btn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
        btn.layer.borderWidth = 1; btn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.5].CGColor;
        btn.tintColor = UIColor.whiteColor;
        [btn setImage:[UIImage systemImageNamed:sClean ? @"eye.slash" : @"eye"] forState:UIControlStateNormal];
        [btn addTarget:SBPHelper.class action:@selector(toggleClean:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
    [sReelTimer invalidate];
    __weak UIViewController *wvc = self;
    sReelTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 repeats:YES block:^(NSTimer *t) {
        UIViewController *s = wvc;
        if (!s.viewIfLoaded.window) { [t invalidate]; return; }
        UIView *b = [s.view viewWithTag:0x5B0B];
        if (!SBBool(@"reels_btn", NO)) { sClean = NO; b.hidden = YES; }
        else b.hidden = NO;
        SBApplyClean(s.view);
        if (b) [s.view bringSubviewToFront:b];
    }];
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    [sReelTimer invalidate]; sReelTimer = nil;
}
%end

#pragma mark - 4) OLED keyboard

@interface UIInputSetHostView : UIView @end

static void SBPaintKB(UIView *v, int depth) {
    NSString *n = NSStringFromClass(v.class);
    if ([n isEqualToString:@"UIKBInputBackdropView"] || [n isEqualToString:@"_UIBackdropView"] ||
        [v isKindOfClass:UIVisualEffectView.class]) { v.hidden = YES; return; }
    if ([n isEqualToString:@"UIKBBackgroundView"]) v.backgroundColor = SBColor(SBStr(@"kb_color", @"#000000"), UIColor.blackColor);
    if (depth > 4) return;
    for (UIView *s in v.subviews) SBPaintKB(s, depth + 1);
}

%hook UIInputSetHostView
- (void)layoutSubviews {
    %orig;
    if (!SBBool(@"oled_kb", NO)) return;
    self.backgroundColor = SBColor(SBStr(@"kb_color", @"#000000"), UIColor.blackColor);
    SBPaintKB(self, 0);
}
%end

%hook UITextField
- (UIKeyboardAppearance)keyboardAppearance {
    UIKeyboardAppearance o = %orig;
    return SBBool(@"oled_kb", NO) ? UIKeyboardAppearanceDark : o;
}
%end

%hook UITextView
- (UIKeyboardAppearance)keyboardAppearance {
    UIKeyboardAppearance o = %orig;
    return SBBool(@"oled_kb", NO) ? UIKeyboardAppearanceDark : o;
}
%end

%hook UISearchBar
- (UIKeyboardAppearance)keyboardAppearance {
    UIKeyboardAppearance o = %orig;
    return SBBool(@"oled_kb", NO) ? UIKeyboardAppearanceDark : o;
}
%end

@interface UIKBRenderConfig : NSObject @end
%hook UIKBRenderConfig
- (BOOL)lightKeyboard {
    BOOL o = %orig;
    return SBBool(@"oled_kb", NO) ? NO : o;
}
%end

#pragma mark - 2) Presence screen (last active time)

static NSString *SBAgo(double ms) {
    NSTimeInterval d = [NSDate date].timeIntervalSince1970 - ms / 1000.0;
    if (d < 60) return @"نشط الآن";
    if (d < 3600) return [NSString stringWithFormat:@"قبل %d د", (int)(d / 60)];
    if (d < 86400) return [NSString stringWithFormat:@"قبل %d س و %d د", (int)(d / 3600), ((int)d % 3600) / 60];
    return [NSString stringWithFormat:@"قبل %d يوم", (int)(d / 86400)];
}

@interface SBPListVC : UITableViewController
@property (nonatomic, strong) NSArray<NSString *> *lines;
@property (nonatomic, assign) BOOL presence;
@end

@implementation SBPListVC
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.presence ? @"آخر نشاط" : @"سجل الإشعارات";
    self.lines = @[@"جاري التحميل…"];
    if (self.presence) [self loadPresence]; else [self loadLog];
}
- (void)loadLog {
    NSMutableArray *o = [NSMutableArray array];
    NSDateFormatter *f = [NSDateFormatter new]; f.dateFormat = @"yyyy/MM/dd HH:mm";
    for (NSDictionary *e in [SBD() arrayForKey:@"log"] ?: @[]) {
        NSString *what = [e[@"t"] isEqualToString:@"story"] ? @"شاف الستوري" : @"زار البروفايل";
        [o addObject:[NSString stringWithFormat:@"@%@ — %@\n%@", e[@"u"], what,
                      [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:[e[@"ts"] doubleValue]]]]];
    }
    self.lines = o.count ? o : @[@"ماكو سجل لحد الآن"];
    [self.tableView reloadData];
}
- (void)loadPresence {
    __weak SBPListVC *ws = self;
    SBGet(@"/direct_v2/get_presence/", ^(NSDictionary *j) {
        NSDictionary *p = j[@"user_presence"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![p isKindOfClass:NSDictionary.class] || !p.count) {
                ws.lines = @[@"ما كدرت أجيب البيانات (تأكد من الجلسة أو من إعدادات حالة النشاط)"];
                [ws.tableView reloadData]; return;
            }
            NSArray *keys = [p keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                return [b[@"last_activity_at_ms"] compare:a[@"last_activity_at_ms"]];
            }];
            if (keys.count > 40) keys = [keys subarrayWithRange:NSMakeRange(0, 40)];
            NSMutableDictionary *names = [([SBD() dictionaryForKey:@"names"] ?: @{}) mutableCopy];
            dispatch_group_t g = dispatch_group_create();
            for (NSString *pk in keys) {
                if (names[pk]) continue;
                dispatch_group_enter(g);
                SBGet([NSString stringWithFormat:@"/users/%@/info/", pk], ^(NSDictionary *uj) {
                    NSString *n = uj[@"user"][@"username"];
                    if (n) @synchronized (names) { names[pk] = n; }
                    dispatch_group_leave(g);
                });
            }
            dispatch_group_notify(g, dispatch_get_main_queue(), ^{
                [SBD() setObject:names forKey:@"names"];
                NSDateFormatter *f = [NSDateFormatter new]; f.dateFormat = @"yyyy/MM/dd HH:mm";
                NSMutableArray *o = [NSMutableArray array];
                for (NSString *pk in keys) {
                    double ms = [p[pk][@"last_activity_at_ms"] doubleValue];
                    [o addObject:[NSString stringWithFormat:@"@%@\n%@ — %@", names[pk] ?: pk, SBAgo(ms),
                                  [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:ms / 1000.0]]]];
                }
                ws.lines = o; [ws.tableView reloadData];
            });
        });
    });
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.lines.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"c"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"];
    c.textLabel.numberOfLines = 0; c.textLabel.text = self.lines[i.row];
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    return c;
}
@end

#pragma mark - Settings screen "شيبوبة بلس"

@interface SBPSettingsVC : UITableViewController
@property (nonatomic, strong) NSArray<NSDictionary *> *secs;
@end

@implementation SBPSettingsVC
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"شيبوبة بلس";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    // y: sw = switch, tx = text prompt, go = action
    self.secs = @[
      @{@"h": @"الرسالة الترحيبية", @"f": @"تطلع شفافة بتوهج نيون أول ما ينفتح البرنامج.", @"i": @[
          @{@"t": @"تفعيل", @"k": @"welcome_on", @"y": @"sw"},
          @{@"t": @"النص", @"k": @"welcome_text", @"y": @"tx", @"d": @"أهلاً بك في شيبوبة بلس"},
          @{@"t": @"اللون (HEX)", @"k": @"welcome_color", @"y": @"tx", @"d": @"#00F6FF"},
          @{@"t": @"حجم الخط", @"k": @"welcome_size", @"y": @"tx", @"d": @"28"},
          @{@"t": @"مدة الظهور (ثواني)", @"k": @"welcome_dur", @"y": @"tx", @"d": @"2.5"},
          @{@"t": @"معاينة", @"y": @"go", @"a": @"preview"}]},
      @{@"h": @"النشاط", @"f": @"آخر ظهور بالساعة والدقيقة لجهات المراسلة.", @"i": @[
          @{@"t": @"عرض آخر نشاط", @"y": @"go", @"a": @"presence"}]},
      @{@"h": @"الريلز", @"f": @"يطلع زر دائري بالريلز: يخفي اللايك والتعليقات والمشاركة والوصف، وترجعهم بنفس الزر.", @"i": @[
          @{@"t": @"زر التصفح النظيف", @"k": @"reels_btn", @"y": @"sw"}]},
      @{@"h": @"الكيبورد", @"f": @"الكيبورد غامق والحروف بيضاء. اللون يغيّر خلفية الكيبورد.", @"i": @[
          @{@"t": @"OLED كيبورد", @"k": @"oled_kb", @"y": @"sw"},
          @{@"t": @"لون الخلفية (HEX)", @"k": @"kb_color", @"y": @"tx", @"d": @"#000000"}]},
      @{@"h": @"الإشعارات", @"f": @"زيارات البروفايل: انستغرام ما يعطي هذي المعلومة لأي تطبيق، لذلك ما موجودة.", @"i": @[
          @{@"t": @"إشعار عند مشاهدة الستوري", @"k": @"story_on", @"y": @"sw"},
          @{@"t": @"فحص الآن", @"y": @"go", @"a": @"checknow"},
          @{@"t": @"سجل الإشعارات", @"y": @"go", @"a": @"logs"}]}
    ];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)preview { SBShowWelcome(YES); }
- (void)presence { SBPListVC *v = [SBPListVC new]; v.presence = YES; [self.navigationController pushViewController:v animated:YES]; }
- (void)logs { [self.navigationController pushViewController:[SBPListVC new] animated:YES]; }
- (void)checknow { SBCheckStoryViewers(YES); }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return self.secs.count; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return [self.secs[s][@"i"] count]; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return self.secs[s][@"h"]; }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s { return self.secs[s][@"f"]; }
- (void)swChanged:(UISwitch *)sw {
    NSString *k = objc_getAssociatedObject(sw, "k");
    [SBD() setBool:sw.isOn forKey:k];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *it = self.secs[ip.section][@"i"][ip.row];
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    c.textLabel.text = it[@"t"];
    NSString *y = it[@"y"];
    if ([y isEqualToString:@"sw"]) {
        UISwitch *sw = [UISwitch new];
        sw.on = SBBool(it[@"k"], NO);
        objc_setAssociatedObject(sw, "k", it[@"k"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sw addTarget:self action:@selector(swChanged:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw; c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if ([y isEqualToString:@"tx"]) {
        c.detailTextLabel.text = SBStr(it[@"k"], it[@"d"]);
    } else {
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *it = self.secs[ip.section][@"i"][ip.row];
    NSString *y = it[@"y"];
    if ([y isEqualToString:@"go"]) {
        SEL s = NSSelectorFromString(it[@"a"]);
        if ([self respondsToSelector:s]) ((void (*)(id, SEL))objc_msgSend)(self, s);
    } else if ([y isEqualToString:@"tx"]) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:it[@"t"] message:nil preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:^(UITextField *f) { f.text = SBStr(it[@"k"], it[@"d"]); }];
        [a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"حفظ" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            [SBD() setObject:a.textFields.firstObject.text forKey:it[@"k"]];
            [t reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
        }]];
        [self presentViewController:a animated:YES completion:nil];
    }
}
@end

static void SBOpenSettings(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = SBTopVC(); if (!top) return;
        if ([top isKindOfClass:UINavigationController.class] &&
            [((UINavigationController *)top).viewControllers.firstObject isKindOfClass:SBPSettingsVC.class]) return;
        UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:[SBPSettingsVC new]];
        n.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        [top presentViewController:n animated:YES completion:nil];
    });
}

#pragma mark - Entry point: hold 3 fingers for ~1s anywhere

static char kGest;
%hook UIWindow
- (void)becomeKeyWindow {
    %orig;
    if (self.rootViewController && !objc_getAssociatedObject(self, &kGest)) {
        UILongPressGestureRecognizer *g = [[UILongPressGestureRecognizer alloc] initWithTarget:SBPHelper.class action:@selector(openGesture:)];
        g.numberOfTouchesRequired = 3; g.minimumPressDuration = 1.0; g.cancelsTouchesInView = NO;
        [self addGestureRecognizer:g];
        objc_setAssociatedObject(self, &kGest, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
%end

#pragma mark - Lifecycle

%ctor {
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil
                                                     queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) {
        static BOOL first = YES;
        if (first) {
            first = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ SBShowWelcome(NO); });
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ SBCheckStoryViewers(NO); });
    }];
    [NSTimer scheduledTimerWithTimeInterval:300 repeats:YES block:^(NSTimer *t) {
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) SBCheckStoryViewers(NO);
    }];
}
