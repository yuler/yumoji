# Yumoji 识别接口约定（草案）

> **状态：草案，待 owner 审阅后定稿。** 后端还没有实现，会在本仓库之外开发。App 目前只有 mock 实现（`MockFoodAnalyzer`），不发任何网络请求。

## 1. 概览

| 项目     | 约定                                           |
| -------- | ---------------------------------------------- |
| Base URL | `https://yumoji.yuler.dev/api`                 |
| 接口     | `POST /v1/analyze`，一张照片进，一条识别结果出 |
| 账号     | 无。用匿名设备 ID 区分设备，只用于限流         |
| 模型 key | 只放在后端。App 不持有任何模型 key             |
| 限流     | 按设备 ID 计每日额度，用完返回 `429`           |

## 2. POST /v1/analyze

上传一张餐食照片，返回菜名、粗估热量和一句话简介。

### 请求

| 位置   | 名称           | 必填 | 说明                         |
| ------ | -------------- | ---- | ---------------------------- |
| Header | `Content-Type` | 是   | 固定为 `image/jpeg`          |
| Header | `X-Device-Id`  | 是   | 匿名设备 ID，见下            |
| Body   | 无字段名       | 是   | JPEG 二进制本身，不超过 2 MB |

- **图片**：上传原图（不是抠好的贴纸），长边缩到 1024 px 以内，小图不放大，JPEG 质量 0.8，通常 100 至 300 KB。App 侧由 `UploadImage.jpegData(from:)` 生成。
- **编码**：请求体直接就是 JPEG 字节，不用 base64 JSON，也不用 multipart。理由：
  - 只有一张图，没有别的字段，元信息放 Header 就够了。
  - base64 会让体积多出约三分之一；multipart 两端都要多写边界的拼装和解析。
  - App 侧一次 `URLSession` 上传即可，后端读完整个 body 就是图片。
- **设备 ID**：App 首次启动时随机生成一个 UUID 并存在本机，之后每次请求都带上。不关联账号，也不取任何硬件标识；卸载重装会换新。

### 成功响应

`200 OK`，`Content-Type: application/json; charset=utf-8`。

| 字段      | 类型            | 说明                                                |
| --------- | --------------- | --------------------------------------------------- |
| `name`    | string          | 菜名；不是食物时写看到的东西                        |
| `kcal`    | integer 或 null | 整份的粗估热量，单位千卡；估不出或不是食物时为 null |
| `intro`   | string          | 一句话简介，不超过 40 个汉字                        |
| `is_food` | boolean         | 照片里是不是食物                                    |

照片不是食物也算识别成功：返回 `200`，`is_food` 为 `false`，`kcal` 为 `null`。App 展示热量时写成「约 xxx 千卡」。

### 错误响应

错误统一返回 JSON：`code` 给程序判断，`message` 是可以直接展示的中文。

```json
{
  "code": "quota_exceeded",
  "message": "今天的识别次数用完了，明天再来"
}
```

| 状态码 | `code`            | 含义                                          |
| ------ | ----------------- | --------------------------------------------- |
| `400`  | `invalid_request` | 缺少 `X-Device-Id`，或请求体不是能解码的 JPEG |
| `413`  | `image_too_large` | 请求体超过 2 MB                               |
| `429`  | `quota_exceeded`  | 这台设备今天的额度用完了                      |
| `502`  | `upstream_failed` | 模型服务出错或超时，可以稍后重试              |
| `500`  | `internal_error`  | 其他服务端错误                                |

App 遇到任何错误都保留贴纸，文字区显示「待识别」和重试按钮；`429` 时重试也不会成功，届时改成展示 `message`。

## 3. 示例

请求：

```http
POST /api/v1/analyze HTTP/1.1
Host: yumoji.yuler.dev
Content-Type: image/jpeg
X-Device-Id: 3F2A9C1E-5B7D-4E0A-9C36-8D1F2B4A6E70
Content-Length: 184302

<JPEG 二进制>
```

响应：

```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8

{
  "name": "番茄炒蛋",
  "kcal": 320,
  "intro": "酸甜开胃的国民家常菜，鸡蛋嫩滑，番茄多汁。",
  "is_food": true
}
```

这段响应 JSON 同时是 App 单元测试的解码样例（`FoodAnalysisTests`），改这里要同步改测试。

## 4. 待 owner 确认

- [ ] 每台设备每天的额度是多少，按哪个时区的零点重置。
- [ ] `429` 是否带 `Retry-After`，好让 App 提示什么时候能再用。
- [ ] 不是食物的照片算不算一次额度。
- [ ] 后端调模型的超时时间，以及 App 侧等多久算失败（建议 20 秒）。
- [ ] 请求体直接放 JPEG 的方案是否合适；如果后端框架更适合 multipart，这里再改。
