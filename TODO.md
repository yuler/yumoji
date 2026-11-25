# Yumoji TODOS

## 1. 抠图动画（参考 CapWords）

现状：抠图阶段仅显示系统 `ProgressView` +「正在抠图…」，完成后直接硬切出贴纸（见 `ios/Yumoji/Views/ResultView.swift`）。

- [x] 抠图期间在舞台区保留展示原图，叠加柔和的扫光 / 呼吸动效
- [x] Vision 抠图完成后，原图背景暗化并淡出，露出暖色贴纸舞台
- [x] 白边贴纸在原位带弹簧缩放/微倾动效弹起并浮出投影，配合轻触觉反馈（Haptics）

## 2. 食物识别接入真实 API

现状：当前默认使用 `MockFoodAnalyzer`（见 `ios/Yumoji/Services/FoodAnalyzing.swift`），等待 1.5s 后从 3 条写死样例中随机返回一条，未发任何网络请求。

- [ ] 确认 `docs/api.md` 中的待定项（每日额度、时区、429 `Retry-After`、非食物是否计额度、超时时间、请求体格式）
- [ ] 确定接入节奏：
  - [ ] 方案 A：等待独立后端 `POST https://yumoji.yuler.dev/api/v1/analyze` 就绪后，实现真实 `FoodAnalyzing` 客户端并替换 `MockFoodAnalyzer`
  - [ ] 方案 B（可选，用于提前真机实测）：临时接入云端视觉模型（如 DeepSeek `deepseek-flash` 或千问 `qwen3-vl-plus`）验证菜名、热量、简介识别质量
- [ ] 生成并持久化匿名 `X-Device-Id`（UUID），完善 `429` 等错误提示与重试交互
