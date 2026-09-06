#!/bin/bash
set -e

# 下载源码
git clone --depth 1 https://github.com/ivaaaan/smug.git /tmp/smug
cd /tmp/smug

# [核心黑科技]: 修复 Termux 的 execve(linker64) 导致的 os.Args 漂移 Bug
# 由于 Termux 为了绕过安卓 SELinux，会强制使用 linker64 启动动态链接程序。
# C 语言程序会由 libc 过滤掉这个额外的 linker 参数，但 Go 是直接读取内核栈的，
# 导致 os.Args[1] 变成了二进制文件的绝对路径！所以我们要打个补丁把它过滤掉。
sed -i 's/os.Args\[1:\]/getArgs()/g' main.go
cat << 'CODE' >> main.go

func getArgs() []string {
	args := os.Args[1:]
	// 如果由于 Termux 拦截，导致第一个参数变成了绝对路径，则直接丢弃它
	if len(args) > 0 && strings.HasPrefix(args[0], "/") && strings.HasSuffix(args[0], "smug") {
		return args[1:]
	}
	return args
}
CODE

# [究极黑科技]: 修复 Go >= 1.20 引入的 faccessat2 导致安卓内核杀进程 (SIGSYS) Bug
# 安卓内核的 seccomp 沙箱不认识较新的 faccessat2 系统调用。
# 我们必须降级回到传统的 android 编译目标，因为标准 Linux 构建必然触发这个调用。
# 但是为了防止 os.Args 漂移 bug，我们前面已经打过 getArgs() 补丁了！
# 所以我们现在可以安全地使用 GOOS=android 来避免 SIGSYS！

GOOS=android GOARCH=arm64 CGO_ENABLED=0 go build -o smug .

cd /tmp/smug
tar -czvf smug.termux.tar.gz smug

cp smug.termux.tar.gz $GITHUB_WORKSPACE/
