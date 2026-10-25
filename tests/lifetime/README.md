# 旧版 GAS 效果生命周期回归

本目录用于宿主锁定的 a360f40 兼容基线，不引入新版效果结果协议。

运行 ./tests/lifetime/Test-EffectLifetime.ps1 -Godot /absolute/path/to/godot.exe。
可选 -OutputDirectory 指定一个新的输出目录；-Rendered 在图形模式复验两个运行阶段。
生成宿主位于系统临时目录，保留各阶段日志和结果，不覆盖既有测试宿主。

独立进程覆盖编辑器导入、仅加载抽象GameplayEffect、创建/复制/保存/重载具体效果，
验证强类型数组、A/B隔离、原地append、过滤与子效果apply/remove，以及实例释放。
严格检查退出码、原生ERROR和退出引用残留；断言通过但退出有资源残留仍判失败。
这个测试不需要Warcraft资产，也不是逻辑帧性能测试。
