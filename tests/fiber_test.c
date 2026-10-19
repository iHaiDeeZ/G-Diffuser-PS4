/* Host test for port/gdx_fiber_ps4.c (same System V ABI on Linux x86-64):
 *   cc -O2 -I<G-Diffuser>/port tests/fiber_test.c <G-Diffuser>/port/gdx_fiber_ps4.c && ./a.out */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "gdx_fiber.h"

static GdxFiber *host, *a, *b;
static int log_[16], n;

static void entry_a(void* arg) {
    volatile double x = 1.5;
    for (int i = 0; i < 3; i++) {
        log_[n++] = 10 + i;
        /* Stack must be 16-byte aligned at a call boundary, or SSE spills crash. */
        if (((uintptr_t) __builtin_frame_address(0) & 15) != 0) { puts("FAIL: misaligned frame"); exit(1); }
        gdx_fiber_switch(b);
        x *= 2.0;
    }
    if (x != 12.0) { puts("FAIL: FP state lost"); exit(1); }
    log_[n++] = (int) (intptr_t) arg;
    gdx_fiber_switch(host);
}

static void entry_b(void* arg) {
    (void) arg;
    for (;;) {
        log_[n++] = 20;
        gdx_fiber_switch(a);
    }
}

int main(void) {
    host = gdx_fiber_convert_thread();
    a = gdx_fiber_create(entry_a, (void*) (intptr_t) 99, 0);
    b = gdx_fiber_create(entry_b, NULL, 64 * 1024);
    gdx_fiber_switch(a);
    static const int want[] = { 10, 20, 11, 20, 12, 20, 99 };
    if (n != 7) { printf("FAIL: %d events\n", n); return 1; }
    for (int i = 0; i < 7; i++)
        if (log_[i] != want[i]) { printf("FAIL: event %d = %d\n", i, log_[i]); return 1; }
    puts("fiber test OK");
    return 0;
}
