# Remote Desktop Manager

已撤销 .NET Invariant Mode，当前 AppImage 已正常打包 ICU，多语言界面可用。

现存问题是内置终端使用 Fcitx5 输入中文时，会将候选操作的原始按键同时发送到终端，导致出现 `^[[A`、`^[[D` 等转义字符；该问题属于 RDM 内置终端的输入处理，当前 AppImage 构建脚本无法修复。
