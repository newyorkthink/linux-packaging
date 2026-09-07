package plugins

import "os"

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
	return env
}
