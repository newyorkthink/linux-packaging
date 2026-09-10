#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

/* GTK3 的 GtkFileChooser 不透明类型；gboolean 的 ABI 为 int。 */
typedef struct _GtkFileChooser GtkFileChooser;
typedef int (*SetCurrentFolder)(GtkFileChooser *, const char *);
static SetCurrentFolder real_set_current_folder;
static pthread_once_t gtk_once = PTHREAD_ONCE_INIT;

/* 主进程加载后恢复原环境，避免把本兼容库传给 JRWeb 或宿主 helper。 */
__attribute__((constructor))
static void restore_preload_environment(void)
{
    const char *saved = getenv("JRIVER_FILECHOOSER_SAVED_PRELOAD");
    if (saved == NULL)
        return;
    if ((*saved ? setenv("LD_PRELOAD", saved, 1) : unsetenv("LD_PRELOAD")) != 0 ||
        unsetenv("JRIVER_FILECHOOSER_SAVED_PRELOAD") != 0) {
        perror("JRiver: restore preload environment");
        _exit(127);
    }
}

static void resolve_gtk(void)
{
    /* JRiver 延迟加载 GTK；从已经加载的 GTK 获取真实函数，兼容 RTLD_LOCAL。 */
    void *gtk = dlopen("libgtk-3.so.0", RTLD_LAZY | RTLD_NOLOAD);
    if (gtk != NULL)
        real_set_current_folder = (SetCurrentFolder)dlsym(gtk, "gtk_file_chooser_set_current_folder");
    if (real_set_current_folder == NULL) {
        fputs("JRiver: cannot resolve GTK file chooser function\n", stderr);
        _exit(127);
    }
}

int gtk_file_chooser_set_current_folder(GtkFileChooser *chooser, const char *filename)
{
    pthread_once(&gtk_once, resolve_gtk);
    if (filename != NULL && filename[0] == '\0') {
        const char *home = getenv("HOME");
        filename = home != NULL && home[0] == '/' ? home : "/";
    }
    return real_set_current_folder(chooser, filename);
}
