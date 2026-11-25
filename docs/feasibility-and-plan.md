# Yumoji（吃吃贴纸）— 项目可行性与实施规划

> 把每一口好吃的，收成一枚贴纸
>
> Every yummy bite, a sticker.

调研日期：2026-11-25。本文结论来自官方文档与公开论文，**尚未写代码或调接口实测**，需要实测的地方在文中单独标出。

## 1. 项目定位

Yumoji = yummy + emoji。拍一下每天吃的，把照片里的食物抠出来做成贴纸收集起来，同时用 AI 估算热量、生成食物简介。贴纸效果参考 CapWords。

- **核心闭环**：拍照 -> 本地抠图 -> 用户确认 -> AI 返回菜名、热量、简介 -> 贴纸收进日历。
- **MVP 范围**：拍照、抠图成贴纸、AI 热量与简介、日历回看。不做账号、同步和社交。

---

## 2. 能力可行性评估

**结论：三个能力都能做。抠图是确定的；热量与简介能出结果，但热量只能当粗估。**

| 能力       | 方案                        | 依赖            | 结论                       |
| ---------- | --------------------------- | --------------- | -------------------------- |
| 拍照       | AVFoundation 或系统相机     | 无              | 无风险                     |
| 抠图做贴纸 | VisionKit / Vision 主体提取 | iOS 17+，纯本地 | 可行，最稳的一环           |
| 菜名与简介 | 云端视觉模型                | 联网            | 可行，识别类任务相对可靠   |
| 热量估算   | 云端视觉模型                | 联网            | 可行，但误差大，只能当粗估 |
| 日历与记录 | SwiftData + 月历视图        | 无              | 无风险                     |

### 抠图做贴纸

- CapWords 用的就是 VisionKit 的主体提取，没有自带模型，识别则交给在线大模型（见参考资料 1）。
- 两个入口：`ImageAnalysisInteraction` 提供现成的主体选择交互；`VNGenerateForegroundInstanceMaskRequest` 直接返回 mask，适合自己合成。
- 不依赖 Apple 智能，iOS 17 及以上都能用，即 iPhone XS / XR 之后的机型。
- 贴纸白边要自己合成：把 mask 膨胀一圈填白，再叠上原图。
- 一盘菜可能被识别成一个主体或多个实例，需要一步「确认 / 点选要哪块」。
- 模拟器跑不了主体提取，要真机调试。

### 热量与简介

- 识别「这是什么菜」比估热量可靠得多，所以菜名和简介问题不大。
- 热量应展示为「约 xxx 千卡」，并允许手改。精度数据见第 5 节。

---

## 3. AI 路线决策

**决定：云端视觉模型做主路线，最低支持 iOS 17，苹果端侧模型不进 MVP。**

| 路线         | 能跑的手机                              | 优点               | 缺点                           |
| ------------ | --------------------------------------- | ------------------ | ------------------------------ |
| 云端视觉模型 | iOS 17 及以上全部机型                   | 受众大，精度更好   | 要联网、要 key，上架前要加代理 |
| 苹果端侧模型 | 仅 iPhone 15 Pro 及以后，国行目前不可用 | 免费、离线、隐私好 | 受众窄，食物场景精度未知       |

选云端的两个理由：

1. 受众大，不挑机型和地区。
2. 自己的测试机是国行 iPhone 14 Pro，端侧模型跑不了，云端路线两个环节都能测。

### 苹果端侧模型的现状

- iOS 27 的 Foundation Models 端侧模型已支持图片输入，`Attachment(image)` 配合 `@Generable` 可以直接输出结构化结果（参考资料 2）。
- 它要求设备支持并开启 Apple 智能，门槛是 A17 Pro 及以后的芯片，官方支持列表从 iPhone 15 Pro 起。iPhone 14 全系和 15、15 Plus 不在列表里；业内通行的解释是内存不够（支持机型为 8GB，这些机型为 6GB），Apple 没有明说。
- 国行目前返回不可用。Apple 2026-10-31 公告首批 Apple 智能功能 12 月随 iOS 27.3 在中国推出，但没提第三方能否调用这个框架（参考资料 3）。
- iOS 27 还开放了 `PrivateCloudComputeLanguageModel`，首次下载量 200 万以下的开发者免费。它是否支持图片输入、国内是否可用，**未确认**。

### 留的口子

AI 层抽成一个接口：输入图片，输出菜名、热量、简介。MVP 只实现云端这一个，以后想加端侧再接，不影响其他部分。

---

## 4. 云端模型候选

两家都是 OpenAI 兼容接口，图片可用 base64 直接传，国内直连。

| 项目       | DeepSeek `deepseek-flash`               | 千问 `qwen3-vl-plus`                           |
| ---------- | --------------------------------------- | ---------------------------------------------- |
| 图片输入   | 支持，2026-09 起原生多模态              | 支持                                           |
| 结构化输出 | 支持 JSON 输出                          | 未确认；文档只标明 `qwen3.7-plus` 等新系列支持 |
| 图片格式   | JPEG、PNG、GIF、WebP，**不含 HEIC**     | 含 HEIC                                        |
| 单图 token | 上限 1024；`detail: low` 会缩到 512×512 | 高 × 宽 / 1024 + 2                             |
| 价格       | 未查                                    | 输入 1 元、输出 10 元每百万 token（32K 以内）  |
| 免费额度   | 未查                                    | 北京地域 100 万 token，开通后 90 天内有效      |
| 现状       | 已有 key，可直接复用                    | 需要开通阿里云百炼                             |

- **建议先用 DeepSeek**，因为已有 key；千问当备选或对照。
- iPhone 默认拍 HEIC，走 DeepSeek 需要先转成 JPEG 再上传。
- 千问一张 1024×1024 的图约一千多 token，粗算一次调用不到 1 分钱。
- **两家都没拿食物照片实测过**，中餐混合菜（炒菜、盖饭、火锅）的识别和热量质量是目前最大的未知数。

---

## 5. 热量估算的精度

公开研究里，云端大模型看照片估热量的误差都不小，而且分量越大越低估。

| 研究                         | 照片类型            | 热量平均绝对百分比误差                   |
| ---------------------------- | ------------------- | ---------------------------------------- |
| 3 个大模型对比（参考资料 4） | 52 张标准化照片     | ChatGPT、Claude 均为 35.8%，Gemini 64.2% |
| SeeFood 基准（参考资料 5）   | 1680 张真实餐食照片 | 最好的模型 86.8%，平均绝对误差 123 千卡  |

- 真实餐食里，午餐和晚餐的误差在 43%～59%，和人类目测的水平（约 55%）接近；纯饮料误差最高（312%），因为看不出含糖量。
- 另一项对 40 个模型的研究（参考资料 6）的结论是：换提示词、多角度拍摄几乎没有帮助，起决定作用的是模型本身；补充配料描述能略微改善。
- 对产品的含义：热量定位成「大概多少」，不做精确记账，不面向需要精确控糖的人群。

---

## 6. MVP 流程与技术栈

流程参考 CapWords：确认这一步正好给 AI 请求留出时间，用一段小动画盖住等待。

```text
拍照 -> 本地抠图 -> 用户确认主体 -> 云端返回菜名 / 热量 / 简介 -> 贴纸入库 -> 日历回看
```

| 模块     | 选型                          | 说明                         |
| -------- | ----------------------------- | ---------------------------- |
| UI       | SwiftUI                       | 最低 iOS 17                  |
| 拍照     | AVFoundation                  | 也可先用系统相机起步         |
| 抠图     | VisionKit / Vision            | 主体提取 + 自己合成白边      |
| AI       | 云端视觉模型，OpenAI 兼容接口 | 藏在一个接口后面，便于换模型 |
| 本地存储 | SwiftData                     | 记录、热量、简介和贴纸图     |
| 日历     | 自绘月历视图                  | 每天展示当日贴纸             |

---

## 7. 命名

- 英文名：**Yumoji**（yummy + emoji）。`yum` 是英文口语里的「好吃！」。
- 中文名：**吃吃贴纸**（暂定）。备选「好吃贴纸」「馋贴」。
- 2026-11-25 用 App Store 搜索接口在美区和国区各查过一遍，`Yumoji` 没有搜到同名应用。这只是搜索结果，最终要以 App Store Connect 创建应用为准；商标没有查，中文名也没有查重。
- 淘汰的候选：`Mealmoji`（已有同名饮食日记应用）、`NomNom Stickers`（和已有的 `Om Nom Stickers` 太像）。`Nomstick`、`Bitepeel` 同样未搜到同名，作为备选。

---

## 8. 待确认事项

- [x] AI 路线：云端做主路线，端侧不进 MVP
- [x] 最低支持的 iOS 版本：iOS 17
- [x] 英文项目名：`Yumoji`（仓库目录 `yumoji`）
- [ ] 用几张自己拍的餐食照片直接调接口，验证菜名、热量、简介的输出质量（写 Swift 之前先做）
- [ ] 云端模型定哪家（建议先 DeepSeek `deepseek-flash`）
- [ ] 中文名最终确定
- [ ] 真机验证抠图效果：一盘多菜、汤面、边缘不清晰的食物
- [ ] 确定 Bundle ID 与 Xcode 工程初始化
- [ ] 上架前：key 代理，以及照片上传云端的隐私说明

---

## 参考资料

1. [Behind the appealing design of CapWords](https://developer.apple.com/articles/capwords/) — Apple Developer
2. [What's new in the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2026/241/) — WWDC26
3. [Apple 智能即将登陆中国](https://www.apple.com.cn/newsroom/2026/10/apple-intelligence-features-are-coming-to-users-in-china/) — Apple 新闻稿
4. [Performance Evaluation of 3 Large Language Models for Nutritional Content Estimation from Food Images](https://pmc.ncbi.nlm.nih.gov/articles/PMC12513282/)
5. [Image-Based Dietary Assessment Using Multimodal Large Language Models](https://pmc.ncbi.nlm.nih.gov/articles/PMC13738896/)
6. [Model Architecture Dominates Nutritional Estimation Accuracy in Vision-Language Systems](<https://cdn.nutrition.org/article/S2475-2991(26)00205-2/pdf>)
7. [Lift subjects from images in your app](https://developer.apple.com/videos/play/wwdc2023/10176/) — WWDC23
8. [DeepSeek Vision 文档](https://api-docs.deepseek.com/guides/vision/)
9. [阿里云百炼模型价格](https://help.aliyun.com/zh/model-studio/model-pricing)
