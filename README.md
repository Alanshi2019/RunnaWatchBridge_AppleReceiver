# RunnaWatchBridge Apple Receiver v6

极简 Apple Watch 接收器：

1. 从相册选择 Runna 截图
2. Apple Vision 本地 OCR
3. 解析训练
4. 创建并排程到 Apple Watch

v6 修复：

- 给有配速的 step 增加 WorkoutKit speed alert
- 保持 warmup / work / recovery / cooldown 的正确结构
- 仍然只有一个主按钮，没有 preview / 手动 Add to Watch

如果 Xcode 报 `WorkoutStep(goal:alert:)` 或 `SpeedRangeAlert` 相关编译错误，把错误截图发回来；这是 WorkoutKit SDK 版本差异，需要按你本机 Xcode 的签名微调。
