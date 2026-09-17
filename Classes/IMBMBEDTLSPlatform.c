#include "mbedtls/platform_time.h"
#include <mach/mach_time.h>
#include <stdint.h>

/*
 * iOS 5.x does not provide clock_gettime(), although the SDK exposes enough
 * POSIX feature macros for Mbed TLS to otherwise select that implementation.
 * Use mach_absolute_time(), which is available on the original iPad and is
 * monotonic, to provide the Mbed TLS millisecond clock.
 */
mbedtls_ms_time_t mbedtls_ms_time(void)
{
    static mach_timebase_info_data_t timebase = { 0, 0 };
    uint64_t ticks;
    uint64_t quotient;
    uint64_t remainder;
    uint64_t nanoseconds;

    if (timebase.denom == 0) {
        if (mach_timebase_info(&timebase) != KERN_SUCCESS || timebase.denom == 0) {
            return 0;
        }
    }

    ticks = mach_absolute_time();

    /* Convert without multiplying the full tick count first, which avoids
     * overflow on long uptimes when numer > 1.
     */
    quotient = ticks / timebase.denom;
    remainder = ticks % timebase.denom;
    nanoseconds = quotient * timebase.numer +
                  (remainder * timebase.numer) / timebase.denom;

    return (mbedtls_ms_time_t)(nanoseconds / 1000000ULL);
}
