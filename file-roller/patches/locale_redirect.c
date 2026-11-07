#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

static char *(*real_bindtextdomain)(const char *, const char *) = NULL;

static char *redirect_bindtextdomain(const char *domainname, const char *dirname) {
    const char *appdir_locale;

    if (!real_bindtextdomain)
        real_bindtextdomain = dlsym(RTLD_NEXT, "bindtextdomain");

    appdir_locale = getenv("APPIMAGE_LOCALE_DIR");
    if (appdir_locale && dirname && strncmp(dirname, "/usr/", 5) == 0)
        return real_bindtextdomain(domainname, appdir_locale);
    return real_bindtextdomain(domainname, dirname);
}

char *bindtextdomain(const char *domainname, const char *dirname) {
    return redirect_bindtextdomain(domainname, dirname);
}

char *libintl_bindtextdomain(const char *domainname, const char *dirname) {
    return redirect_bindtextdomain(domainname, dirname);
}
