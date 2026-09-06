#!/bin/bash
set -e

echo "Building smug for Termux..."
git clone --depth 1 https://github.com/ivaaaan/smug.git /tmp/smug
cd /tmp/smug

# 核心：编译为 Android 兼容格式
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -buildmode=pie -o smug .

# 打包为压缩包
tar -czvf smug.termux.tar.gz smug

# 移动到 GitHub Actions 的根目录供上传使用
mv smug.termux.tar.gz $GITHUB_WORKSPACE/
