// Dev aid: a virtual pointer (wlr-virtual-pointer) that sends real motion,
// so hover can be tested in a nested Hyprland (hyprctl's cursor warp gives no
// motion events). Reads commands from stdin, one per line:
//   move X Y            jump to X,Y (layout pixels)
//   glide X Y MS        move there in small steps over MS milliseconds
//   click [left|right]  press and release
//   scroll DY           vertical scroll
//   sleep MS
// Usage: WAYLAND_DISPLAY=<nested> vpointer WIDTH HEIGHT < script
// Built by scripts/vpointer.sh; never installed.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <linux/input-event-codes.h>
#include <wayland-client.h>
#include "wlr-virtual-pointer-unstable-v1-client-protocol.h"

static struct zwlr_virtual_pointer_manager_v1 *manager;
static struct wl_seat *seat;

static void global(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t ver) {
    if (!strcmp(iface, zwlr_virtual_pointer_manager_v1_interface.name))
        manager = wl_registry_bind(r, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
    else if (!strcmp(iface, wl_seat_interface.name) && !seat)
        seat = wl_registry_bind(r, name, &wl_seat_interface, 1);
}
static void global_remove(void *d, struct wl_registry *r, uint32_t name) {}
static const struct wl_registry_listener listener = { global, global_remove };

static uint32_t now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}
static void sleep_ms(int ms) { usleep(ms * 1000); }

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: vpointer WIDTH HEIGHT < commands\n");
        return 2;
    }
    const uint32_t W = atoi(argv[1]), H = atoi(argv[2]);
    struct wl_display *dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "no wayland display\n"); return 1; }
    struct wl_registry *reg = wl_display_get_registry(dpy);
    wl_registry_add_listener(reg, &listener, NULL);
    wl_display_roundtrip(dpy);
    if (!manager) { fprintf(stderr, "compositor lacks zwlr_virtual_pointer_manager_v1\n"); return 1; }
    struct zwlr_virtual_pointer_v1 *p = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, seat);
    double cx = W / 2.0, cy = H / 2.0;
    char line[256];
    while (fgets(line, sizeof line, stdin)) {
        double x, y; int ms; char btn[16] = "left";
        if (sscanf(line, "move %lf %lf", &x, &y) == 2) {
            zwlr_virtual_pointer_v1_motion_absolute(p, now_ms(), x, y, W, H);
            zwlr_virtual_pointer_v1_frame(p);
            cx = x; cy = y;
        } else if (sscanf(line, "glide %lf %lf %d", &x, &y, &ms) == 3) {
            int steps = ms / 8 > 1 ? ms / 8 : 1;
            for (int i = 1; i <= steps; i++) {
                double px = cx + (x - cx) * i / steps, py = cy + (y - cy) * i / steps;
                zwlr_virtual_pointer_v1_motion_absolute(p, now_ms(), px, py, W, H);
                zwlr_virtual_pointer_v1_frame(p);
                wl_display_flush(dpy);
                sleep_ms(8);
            }
            cx = x; cy = y;
        } else if (!strncmp(line, "click", 5)) {
            sscanf(line, "click %15s", btn);
            uint32_t b = !strcmp(btn, "right") ? BTN_RIGHT : BTN_LEFT;
            zwlr_virtual_pointer_v1_button(p, now_ms(), b, WL_POINTER_BUTTON_STATE_PRESSED);
            zwlr_virtual_pointer_v1_frame(p);
            wl_display_flush(dpy);
            sleep_ms(30);
            zwlr_virtual_pointer_v1_button(p, now_ms(), b, WL_POINTER_BUTTON_STATE_RELEASED);
            zwlr_virtual_pointer_v1_frame(p);
        } else if (sscanf(line, "scroll %lf", &y) == 1) {
            zwlr_virtual_pointer_v1_axis(p, now_ms(), WL_POINTER_AXIS_VERTICAL_SCROLL, wl_fixed_from_double(y));
            zwlr_virtual_pointer_v1_frame(p);
        } else if (sscanf(line, "sleep %d", &ms) == 1) {
            wl_display_flush(dpy);
            sleep_ms(ms);
        }
        wl_display_flush(dpy);
    }
    wl_display_roundtrip(dpy);
    zwlr_virtual_pointer_v1_destroy(p);
    wl_display_roundtrip(dpy);
    return 0;
}
