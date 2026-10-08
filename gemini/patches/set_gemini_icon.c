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

  display = XOpenDisplay(NULL);
  if (display == NULL) {
    free(icon);
    return 0;
  }
  icon_atom = XInternAtom(display, "_NET_WM_ICON", False);
  for (round = 0; round < 90 && getppid() != 1; round++) {
    apply_icon(display, DefaultRootWindow(display), icon_atom, icon, pixel_count + 2);
    XFlush(display);
    usleep(500000);
  }
  XCloseDisplay(display);
  free(icon);
  return 0;
}
