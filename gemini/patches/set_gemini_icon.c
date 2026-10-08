/* 把官方图标写进 WM_CLASS=gemini 窗口的 _NET_WM_ICON。
 * FastTab 先读这个属性，Electron 默认会放上原子图。
 * 参数是 png_to_argb.py 写出的小端文件：width、height、ARGB。
 */
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int ignore_x_error(Display *display, XErrorEvent *event) {
  (void)display;
  (void)event;
  return 0;
}

static void shrink_icon(long **icon, unsigned long *count) {
  long *source = *icon;
  uint32_t width = (uint32_t)source[0];
  uint32_t height = (uint32_t)source[1];
  uint32_t target = 128;
  uint32_t new_width = width;
  uint32_t new_height = height;
  unsigned long new_pixels;
  long *smaller;
  unsigned long y;
  unsigned long x;

  if (width <= target && height <= target) return;
  if (width >= height) {
    new_width = target;
    new_height = (uint32_t)(((unsigned long)height * target) / width);
  } else {
    new_height = target;
    new_width = (uint32_t)(((unsigned long)width * target) / height);
  }
  if (new_width == 0) new_width = 1;
  if (new_height == 0) new_height = 1;
  new_pixels = (unsigned long)new_width * (unsigned long)new_height;
  smaller = calloc(new_pixels + 2, sizeof(long));
  if (smaller == NULL) return;
  smaller[0] = new_width;
  smaller[1] = new_height;
  for (y = 0; y < new_height; y++) {
    uint32_t src_y = (uint32_t)((y * height) / new_height);
    for (x = 0; x < new_width; x++) {
      uint32_t src_x = (uint32_t)((x * width) / new_width);
      smaller[2 + y * new_width + x] = source[2 + (unsigned long)src_y * width + src_x];
    }
  }
  free(source);
  *icon = smaller;
  *count = new_pixels + 2;
}

static int same_gemini(const unsigned char *value, unsigned long available) {
  static const unsigned char name[] = "gemini";
  if (available < sizeof(name) - 1) return 0;
  for (size_t i = 0; i < sizeof(name) - 1; i++) {
    if (tolower(value[i]) != name[i]) return 0;
  }
  return available == sizeof(name) - 1 || value[sizeof(name) - 1] == '\0';
}

static int window_is_gemini(Display *display, Window window) {
  Atom property = XInternAtom(display, "WM_CLASS", False);
  Atom actual = None;
  int format = 0;
  unsigned long count = 0;
  unsigned long remaining = 0;
  unsigned char *data = NULL;
  int matches = 0;

  if (XGetWindowProperty(display, window, property, 0, 64, False, XA_STRING,
                         &actual, &format, &count, &remaining, &data) != Success ||
      data == NULL) {
    return 0;
  }
  if (count > 0 && same_gemini(data, count)) matches = 1;
  for (unsigned long i = 0; i + 1 < count; i++) {
    if (data[i] == '\0' && same_gemini(data + i + 1, count - i - 1)) matches = 1;
  }
  XFree(data);
  return matches;
}

static void apply_icon(Display *display, Window window, Atom icon_atom, long *icon,
                       unsigned long count) {
  if (window_is_gemini(display, window)) {
    XChangeProperty(display, window, icon_atom, XA_CARDINAL, 32, PropModeReplace,
                    (unsigned char *)icon, count);
  }

  Window root = None;
  Window parent = None;
  Window *children = NULL;
  unsigned int child_count = 0;
  if (!XQueryTree(display, window, &root, &parent, &children, &child_count)) return;
  for (unsigned int i = 0; i < child_count; i++) {
    apply_icon(display, children[i], icon_atom, icon, count);
  }
  if (children != NULL) XFree(children);
}

int main(int argc, char **argv) {
  FILE *file = NULL;
  uint32_t width = 0;
  uint32_t height = 0;
  unsigned long pixel_count = 0;
  long *icon = NULL;
  Display *display = NULL;
  Atom icon_atom = None;
  int round = 0;

  if (argc != 2) return 2;
  file = fopen(argv[1], "rb");
  if (file == NULL) return 1;
  if (fread(&width, sizeof(width), 1, file) != 1 ||
      fread(&height, sizeof(height), 1, file) != 1 || width == 0 || height == 0 ||
      width > 1024 || height > 1024) {
    fclose(file);
    return 1;
  }
  pixel_count = (unsigned long)width * (unsigned long)height;
  icon = calloc(pixel_count + 2, sizeof(long));
  if (icon == NULL) {
    fclose(file);
    return 1;
  }
  icon[0] = width;
  icon[1] = height;
  for (unsigned long i = 0; i < pixel_count; i++) {
    uint32_t pixel = 0;
    if (fread(&pixel, sizeof(pixel), 1, file) != 1) {
      free(icon);
      fclose(file);
      return 1;
    }
    icon[i + 2] = pixel;
  }
  fclose(file);
  pixel_count += 2;
  shrink_icon(&icon, &pixel_count);

  display = XOpenDisplay(NULL);
  if (display == NULL) {
    free(icon);
    return 0;
  }
  XSetErrorHandler(ignore_x_error);
  icon_atom = XInternAtom(display, "_NET_WM_ICON", False);
  for (round = 0; round < 120; round++) {
    apply_icon(display, DefaultRootWindow(display), icon_atom, icon, pixel_count);
    XFlush(display);
    usleep(500000);
  }
  XCloseDisplay(display);
  free(icon);
  return 0;
}
