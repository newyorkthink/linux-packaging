package execute

import (
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
)

var termuxLinker string

func init() {
	executable, err := os.Executable()
	if err == nil && filepath.Base(executable) == "linker64" {
		termuxLinker = executable
	}
}

// termuxCommand 沿用 smug 的 shell 执行链，保留上游 Bash 命令及参数。
func termuxCommand(name string, args ...string) *exec.Cmd {
	cmd := exec.Command(name, args...)
	if termuxLinker == "" || cmd.Err != nil {
		return cmd
	}

	// Go 的直接 execve 不经过 termux-exec；先由 linker 启动 Termux sh。
	shell, err := exec.LookPath("sh")
	if err != nil {
		cmd.Err = err
		return cmd
	}

	// 每个参数独立传给 "$@"，不把参数拼接成新的 shell 代码。
	argv := []string{shell, "-c", `exec "$@"`, name, cmd.Path}
	argv = append(argv, args...)
	return exec.Command(termuxLinker, argv...)
}

// TermuxExec 供 asdf exec、shim 和插件扩展使用，保留替换当前进程的语义。
func TermuxExec(executablePath string, args []string, env []string) error {
	if termuxLinker == "" {
		return syscall.Exec(executablePath, append([]string{executablePath}, args...), env)
	}

	cmd := termuxCommand(executablePath, args...)
	if cmd.Err != nil {
		return cmd.Err
	}
	// 使用上游传入的完整环境及当前标准输入输出，不额外创建父进程。
	return syscall.Exec(cmd.Path, cmd.Args, env)
}
