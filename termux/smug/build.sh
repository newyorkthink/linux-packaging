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

# 编译为 Linux 标准 PIE 格式
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -buildmode=pie -o smug .

# 使用 termux-elf-cleaner 自动修复 Android Bionic 的 64字节 TLS 对齐限制
sudo apt-get update && sudo apt-get install -y build-essential cmake
git clone https://github.com/termux/termux-elf-cleaner.git /tmp/termux-elf-cleaner
cd /tmp/termux-elf-cleaner
cmake . && make
./termux-elf-cleaner /tmp/smug/smug

cd /tmp/smug
tar -czvf smug.termux.tar.gz smug

cp smug.termux.tar.gz $GITHUB_WORKSPACE/
