// simtime_hooks.m - DYLD interposes for the wall-clock APIs commonly read
// inside iOS apps. NSDate / Foundation date APIs ultimately call
// CFAbsoluteTimeGetCurrent → gettimeofday, so hooking the C entry points
// gets the Swift / Objective-C layers for free.
//
// Monotonic clocks (mach_absolute_time, CLOCK_MONOTONIC, CLOCK_UPTIME_RAW)
// are deliberately NOT mocked when frozen - freezing the monotonic clock
// freezes UIKit's animation/timer subsystem too, and the UI looks dead.
// When scaling, monotonic also stays real for v0; we revisit if/when users
// hit timer-doesn't-fire-during-scale bugs.

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <sys/time.h>
#import <time.h>
#import <mach/mach_time.h>

#import "simtime_state.h"

// Apple's official interpose macro - works inside dylibs loaded via
// DYLD_INSERT_LIBRARIES. Defined here so we don't depend on macOS-only
// headers and so the contract is visible.
#define DYLD_INTERPOSE(_replacement, _replacee) \
   __attribute__((used)) static struct{ const void* replacement; const void* replacee; } \
   _interpose_##_replacee \
   __attribute__ ((section ("__DATA,__interpose"))) = { \
       (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };

// MARK: - gettimeofday

static int simtime_gettimeofday(struct timeval *tv, void *tz) {
    int rc = gettimeofday(tv, tz);
    if (rc != 0 || !tv) return rc;
    double real = (double)tv->tv_sec + (double)tv->tv_usec / 1e6;
    double mock = simtime_mock_seconds(real);
    if (mock == real) return rc;
    tv->tv_sec = (time_t)mock;
    tv->tv_usec = (suseconds_t)((mock - (double)tv->tv_sec) * 1e6);
    return rc;
}
DYLD_INTERPOSE(simtime_gettimeofday, gettimeofday)

// MARK: - clock_gettime - only CLOCK_REALTIME, leave monotonic alone

static int simtime_clock_gettime(clockid_t clk, struct timespec *ts) {
    int rc = clock_gettime(clk, ts);
    if (rc != 0 || !ts) return rc;
    if (clk != CLOCK_REALTIME) return rc;  // never touch monotonic
    double real = (double)ts->tv_sec + (double)ts->tv_nsec / 1e9;
    double mock = simtime_mock_seconds(real);
    if (mock == real) return rc;
    ts->tv_sec = (time_t)mock;
    ts->tv_nsec = (long)((mock - (double)ts->tv_sec) * 1e9);
    return rc;
}
DYLD_INTERPOSE(simtime_clock_gettime, clock_gettime)

// MARK: - time

static time_t simtime_time(time_t *t) {
    time_t real = time(NULL);
    time_t mock = (time_t)simtime_mock_seconds((double)real);
    if (t) *t = mock;
    return mock;
}
DYLD_INTERPOSE(simtime_time, time)

// MARK: - CFAbsoluteTimeGetCurrent
//
// CFAbsoluteTimeGetCurrent returns seconds since the CF reference date
// (2001-01-01 00:00:00 UTC = 978307200 unix). NSDate.now / [NSDate date]
// route through here. Hooking the C entry catches both Swift and Obj-C
// callers without separate method swizzles.

#define CF_REFERENCE_UNIX 978307200.0

static CFAbsoluteTime simtime_CFAbsoluteTimeGetCurrent(void) {
    CFAbsoluteTime real = CFAbsoluteTimeGetCurrent();
    double real_unix = (double)real + CF_REFERENCE_UNIX;
    double mock_unix = simtime_mock_seconds(real_unix);
    if (mock_unix == real_unix) return real;
    return (CFAbsoluteTime)(mock_unix - CF_REFERENCE_UNIX);
}
DYLD_INTERPOSE(simtime_CFAbsoluteTimeGetCurrent, CFAbsoluteTimeGetCurrent)

// MARK: - constructor: log injection so we know it loaded

__attribute__((constructor))
static void simtime_init(void) {
    const char *udid = getenv("SIMTIME_UDID");
    const char *bundle = getenv("SIMTIME_BUNDLE");
    if (!udid || !bundle) {
        NSLog(@"[simtime] loaded but SIMTIME_UDID/SIMTIME_BUNDLE not set - pass-through mode");
        return;
    }
    NSLog(@"[simtime] loaded for %s/%s", udid, bundle);
}
