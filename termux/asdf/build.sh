#!/bin/bash
set -e

echo "Building asdf for Termux..."
git clone --depth 1 https://github.com/asdf-vm/asdf.git /tmp/asdf
cd /tmp/asdf

# 核心：编译为 Android 兼容格式。asdf 的主程序在 cmd/asdf 目录下
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -buildmode=pie -o asdf ./cmd/asdf

# 打包为压缩包
tar -czvf asdf.termux.tar.gz asdf

# 移动到 GitHub Actions 的根目录供上传使用
mv asdf.termux.tar.gz $GITHUB_WORKSPACE/
