package main

import (
	"os"
)

func fixTermuxArgs() {
	if len(os.Args) < 2 {
		return
	}

	// Termux Android linker64 启动时可能多插入一个参数：
	// /system/bin/linker64 /data/data/com.termux/files/usr/bin/asdf plugin add python
	//
	// 修正为：
	// /data/data/com.termux/files/usr/bin/asdf plugin add python

	if os.Args[0] != "/data/data/com.termux/files/usr/bin/asdf" &&
		len(os.Args) > 1 &&
		os.Args[1] == "/data/data/com.termux/files/usr/bin/asdf" {

		os.Args = append([]string{os.Args[1]}, os.Args[2:]...)
	}
}
