// test_clock - tiny iOS-Sim binary that prints every clock API simtime hooks.
// Used to verify the dylib end-to-end: inject via DYLD_INSERT_LIBRARIES, run,
// confirm output reflects the mocked time.

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <sys/time.h>
#import <time.h>
#import <stdio.h>

int main(void) {
    @autoreleasepool {
        // gettimeofday
        struct timeval tv;
        gettimeofday(&tv, NULL);
        printf("gettimeofday:           %lld.%06d\n", (long long)tv.tv_sec, tv.tv_usec);

        // clock_gettime(CLOCK_REALTIME)
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);
        printf("clock_gettime REALTIME: %lld.%09ld\n", (long long)ts.tv_sec, ts.tv_nsec);

        // clock_gettime(CLOCK_MONOTONIC) - should NOT be mocked
        clock_gettime(CLOCK_MONOTONIC, &ts);
        printf("clock_gettime MONOTONIC: %lld.%09ld (real, never mocked)\n",
               (long long)ts.tv_sec, ts.tv_nsec);

        // time()
        time_t t = time(NULL);
        printf("time():                  %lld\n", (long long)t);

        // CFAbsoluteTimeGetCurrent (NSDate / Swift Date.now use this)
        CFAbsoluteTime cf = CFAbsoluteTimeGetCurrent();
        printf("CFAbsoluteTimeGetCurrent: %.6f\n", cf);

        // [NSDate date] - should agree with CFAbsoluteTime path
        NSDate *now = [NSDate date];
        printf("[NSDate date]:           %s\n", [[now description] UTF8String]);
        printf("[NSDate timeIntervalSince1970]: %.6f\n", [now timeIntervalSince1970]);
    }
    return 0;
}
