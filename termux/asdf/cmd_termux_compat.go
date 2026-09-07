package main

import (
	"os"
	"path/filepath"
)

func init() {
	fixTermuxArgs()
}

func fixTermuxArgs() {
	// 与 smug 的已验证实现一致，按实际进程入口识别 linker 模式。
	// 正常直接启动时不删参数，不依赖安装路径或程序文件名。
	executable, err := os.Executable()
	if err == nil && filepath.Base(executable) == "linker64" && len(os.Args) > 1 {
		os.Args = os.Args[1:]
	}
}
