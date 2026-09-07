package plugins

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
)

// termuxPythonInstallEnv 仅作用于 Python 安装，不修改进程全局环境。
func termuxPythonInstallEnv(plugin, callback string, environment map[string]string) map[string]string {
	if plugin != "python" || callback != "install" {
		return environment
	}

	// 复制回调环境，保留调用方及其他插件的原有设置。
	env := make(map[string]string, len(environment)+5)
	for key, value := range environment {
		env[key] = value
	}

	defaults := map[string]string{
		// 对齐 Termux 的特性禁用方式，避开日志中四个未声明函数。
		"ac_cv_func_close_range":     "no",
		"ac_cv_func_copy_file_range": "no",
		"ac_cv_func_preadv2":         "no",
		"ac_cv_func_pwritev2":        "no",
		// 沿用 Termux 官方配置，避免 shutil 复制 SELinux 扩展属性失败。
		"ac_cv_header_sys_xattr_h": "no",
		// CPython configure 支持 LN，生成的 Makefile 使用软链接。
		"LN": "ln -s",
	}
	for key, value := range defaults {
		if env[key] != "" {
			continue
		}
		// 显式传入的设置优先；只在缺省时补充兼容值。
		if inherited := os.Getenv(key); inherited != "" {
			env[key] = inherited
		} else {
			env[key] = value
		}
	}

	// CPython 的扩展探测还会自行搜索文件，需要显式传入 Termux 目录。
	getEnv := func(key string) string {
		if value, ok := env[key]; ok {
			return value
		}
		return os.Getenv(key)
	}
	if prefix := getEnv("PREFIX"); prefix != "" {
		for key, flag := range map[string]string{
			"CPPFLAGS": "-I" + filepath.Join(prefix, "include"),
			"LDFLAGS":  "-L" + filepath.Join(prefix, "lib"),
		} {
			existing := getEnv(key)
			if !slices.Contains(strings.Fields(existing), flag) {
				env[key] = strings.TrimSpace(existing + " " + flag)
			}
		}
		// 保留已有 pkg-config 搜索顺序，避免覆盖自定义依赖配置。
		pkgConfigPath := getEnv("PKG_CONFIG_PATH")
		pkgConfigDir := filepath.Join(prefix, "lib", "pkgconfig")
		if !slices.Contains(filepath.SplitList(pkgConfigPath), pkgConfigDir) {
			if pkgConfigPath == "" {
				env["PKG_CONFIG_PATH"] = pkgConfigDir
			} else {
				env["PKG_CONFIG_PATH"] = pkgConfigPath + string(os.PathListSeparator) + pkgConfigDir
			}
		}
	}
	return env
}
