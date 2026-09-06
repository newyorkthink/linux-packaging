package main

import (
	"os"
	"os/exec"
	"path/filepath"
)

var termuxLinker string

func init() {
	// 无 CGO 的 Go 从原始栈读取参数；linker 启动会多出一个可执行文件参数。
	// 通过实际进程入口识别此模式，正常直接启动时不删除任何参数。
	executable, err := os.Executable()
	if err != nil || filepath.Base(executable) != "linker64" {
		return
	}
	termuxLinker = executable
	if len(os.Args) > 1 {
		os.Args = os.Args[1:]
	}
}

// termuxCommand 保留上游参数，在 linker 模式下由 Termux shell 启动子进程。
func termuxCommand(name string, args ...string) *exec.Cmd {
	cmd := exec.Command(name, args...)
	if termuxLinker == "" || cmd.Err != nil {
		return cmd
	}

	// Go 的直接 execve 不经过 termux-exec；先用系统 linker 启动 Termux sh。
	// sh 的 libc exec 接口随后按当前 Termux 环境处理 tmux、脚本和编辑器。
	shell, err := exec.LookPath("sh")
	if err != nil {
		cmd.Err = err
		return cmd
	}

	// 每个参数独立传递给 "$@"，不把配置路径或参数拼成 shell 代码。
	argv := []string{shell, "-c", `exec "$@"`, name, cmd.Path}
	argv = append(argv, args...)
	return exec.Command(termuxLinker, argv...)
}
