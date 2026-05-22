// simtime_state.m - loads and caches the JSON state file written by the
// simtime CLI. Read on every hooked time call; mtime caching keeps the
// fast path to a single stat(2).

#import <Foundation/Foundation.h>
#import <pthread.h>
#import <sys/stat.h>
#import <sys/time.h>

#import "simtime_state.h"

typedef enum {
    SIMTIME_MODE_REAL = 0,
    SIMTIME_MODE_FROZEN = 1,
    SIMTIME_MODE_SCALED = 2,
} simtime_mode_t;

typedef struct {
    simtime_mode_t mode;
    double frozen_at;           // unix epoch seconds, mode == FROZEN
    double scaled_real_anchor;  // unix epoch seconds, mode == SCALED
    double scaled_mock_anchor;  // unix epoch seconds, mode == SCALED
    double scale;               // mode == SCALED
    uint64_t revision;
} simtime_cached_state_t;

static simtime_cached_state_t g_state = { .mode = SIMTIME_MODE_REAL, .scale = 1.0 };
static char g_path[1024] = { 0 };
static time_t g_last_mtime = 0;
static long g_last_mtime_ns = 0;
static pthread_rwlock_t g_lock = PTHREAD_RWLOCK_INITIALIZER;
static int g_disabled = 0;

// Foundation/CoreFoundation transitively call into our hooks (NSJSONSerialization
// uses CFAbsoluteTimeGetCurrent etc.). A thread-local guard ensures hooks
// triggered from inside our own state-load path go straight through to the
// original implementations.
static pthread_key_t g_reentry_key;
static pthread_once_t g_reentry_once = PTHREAD_ONCE_INIT;
static void simtime_reentry_key_init(void) { pthread_key_create(&g_reentry_key, NULL); }
static int simtime_in_hook(void) {
    pthread_once(&g_reentry_once, simtime_reentry_key_init);
    return pthread_getspecific(g_reentry_key) != NULL;
}
static void simtime_enter_hook(void) {
    pthread_once(&g_reentry_once, simtime_reentry_key_init);
    pthread_setspecific(g_reentry_key, (void *)1);
}
static void simtime_leave_hook(void) {
    pthread_setspecific(g_reentry_key, NULL);
}

static void simtime_resolve_path(void) {
    if (g_path[0]) return;
    const char *udid = getenv("SIMTIME_UDID");
    const char *bundle = getenv("SIMTIME_BUNDLE");
    if (!udid || !bundle) {
        g_disabled = 1;
        return;
    }
    snprintf(g_path, sizeof(g_path), "/private/tmp/simtime-%s-%s.json", udid, bundle);
}

static double simtime_date_from_iso(NSString *s) {
    if (!s) return 0;
    static NSISO8601DateFormatter *f1, *f2;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        f1 = [[NSISO8601DateFormatter alloc] init];
        f1.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        f2 = [[NSISO8601DateFormatter alloc] init];
        f2.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    NSDate *d = [f1 dateFromString:s];
    if (!d) d = [f2 dateFromString:s];
    return d ? d.timeIntervalSince1970 : 0;
}

static void simtime_reload_unlocked(void) {
    NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:g_path]];
    if (!data) {
        g_state.mode = SIMTIME_MODE_REAL;
        return;
    }
    NSError *err = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return;

    NSString *modeStr = dict[@"mode"];
    if ([modeStr isEqualToString:@"frozen"]) {
        g_state.mode = SIMTIME_MODE_FROZEN;
    } else if ([modeStr isEqualToString:@"scaled"]) {
        g_state.mode = SIMTIME_MODE_SCALED;
    } else {
        g_state.mode = SIMTIME_MODE_REAL;
    }
    g_state.frozen_at = simtime_date_from_iso(dict[@"frozenAt"]);
    g_state.scaled_real_anchor = simtime_date_from_iso(dict[@"scaledRealAnchor"]);
    g_state.scaled_mock_anchor = simtime_date_from_iso(dict[@"scaledMockAnchor"]);
    NSNumber *scale = dict[@"scale"];
    g_state.scale = scale ? [scale doubleValue] : 1.0;
    NSNumber *rev = dict[@"revision"];
    g_state.revision = rev ? [rev unsignedLongLongValue] : 0;
}

// Maps a real wall-clock instant to the mocked instant, using whatever mode
// is currently active. Cheap - single stat(2) on the fast path.
double simtime_mock_seconds(double real_seconds) {
    if (g_disabled) return real_seconds;
    if (simtime_in_hook()) return real_seconds; // re-entry from Foundation
    simtime_enter_hook();
    simtime_resolve_path();
    if (g_disabled) { simtime_leave_hook(); return real_seconds; }

    // Cheap mtime check under read lock.
    struct stat st;
    if (stat(g_path, &st) != 0) {
        // No state file → real mode.
        pthread_rwlock_wrlock(&g_lock);
        g_state.mode = SIMTIME_MODE_REAL;
        g_last_mtime = 0;
        g_last_mtime_ns = 0;
        pthread_rwlock_unlock(&g_lock);
        simtime_leave_hook();
        return real_seconds;
    }
    if (st.st_mtimespec.tv_sec != g_last_mtime ||
        st.st_mtimespec.tv_nsec != g_last_mtime_ns) {
        pthread_rwlock_wrlock(&g_lock);
        simtime_reload_unlocked();
        g_last_mtime = st.st_mtimespec.tv_sec;
        g_last_mtime_ns = st.st_mtimespec.tv_nsec;
        pthread_rwlock_unlock(&g_lock);
    }

    pthread_rwlock_rdlock(&g_lock);
    double out;
    switch (g_state.mode) {
        case SIMTIME_MODE_FROZEN:
            out = g_state.frozen_at > 0 ? g_state.frozen_at : real_seconds;
            break;
        case SIMTIME_MODE_SCALED:
            if (g_state.scaled_real_anchor > 0 && g_state.scaled_mock_anchor > 0 && g_state.scale > 0) {
                double elapsed = real_seconds - g_state.scaled_real_anchor;
                out = g_state.scaled_mock_anchor + elapsed * g_state.scale;
            } else {
                out = real_seconds;
            }
            break;
        case SIMTIME_MODE_REAL:
        default:
            out = real_seconds;
            break;
    }
    pthread_rwlock_unlock(&g_lock);
    simtime_leave_hook();
    return out;
}

// True if currently mocking (frozen or scaled). Used by hooks to take the
// fast path on the common no-mocking case.
int simtime_active(void) {
    if (g_disabled) return 0;
    pthread_rwlock_rdlock(&g_lock);
    int active = (g_state.mode != SIMTIME_MODE_REAL);
    pthread_rwlock_unlock(&g_lock);
    return active;
}
