# iOS: MiniMax-H3-Image 入口（feat/ios-image）

在 weiwei-custom 基础上为 iOS 客户端新增 MiniMax-H3-Image，id 与服务端约定一致：`minimax_h3_image`。

## 调研结论（为什么只改三处）

iOS 端模型列表**不是纯服务端下发**：`ios_app/Sources/LocalizationAndModels.swift` 里有本地静态目录
`OPEN_MODEL_CATALOG: [OpenModelSpec]`（`IOSStudioViewModel.allAvailableModels = OPEN_MODEL_CATALOG + customModels`），
与服务端 `app.py` 的 `MODEL_CATALOG` 一一镜像（id / repo_id / modality / defaultFiles 命名都对应）。
所以新模型必须在客户端目录里加条目，不能只靠服务端。

生成分发则是全通用的、按 modality 走：
- `IOSStudioViewModel.generate()` 的 payload 对所有模型同构：`model_id / task_mode / visual_prompt /
  width / height / num_inference_steps / seed / randomize_seed / batch_count`；
  `taskModeId ∈ {fl2va, i2v, i2i_edit, vlm}` 时自动附 `first_frame_base64 / last_frame_base64`。
- `WorkspaceViews.swift` 的参考图选择器对 `fl2va / i2i_edit` 统一出现（PhotosPicker，相册选图）。
- 步数滑杆（4...50）、随机种子开关、批量数对所有模型通用；切换模型时
  `switchSelectedModel()` 用条目的 `defaultSteps` 重置步数。

因此文生图+改图、提示词、seed 全部靠新条目的 `modes: [t2i, i2i_edit]` + `modality: .image` 自动获得，
没有新造任何参数组件。唯一需要按模型区分的是尺寸：现有 `IMAGE_RESOLUTIONS` 只有约 1MP，
装不下 H3-Image 的原生 4MP/8MP/16MP。

## 改动清单

1. `ios_app/Sources/LocalizationAndModels.swift`
   - `OPEN_MODEL_CATALOG` 在 `minimax_h3` 之后新增 `minimax_h3_image` 条目：
     repo `MiniMaxAI/MiniMax-H3-Image`、modality `.image`、`defaultSteps: 6`（6 步蒸馏、无 CFG）、
     modes 为 `t2i`（原生文生图）+ `i2i_edit`（参考图改图）、`approxSizeGB: 68.6`
     （只计新增下载：生图 DiT 66.3 GB + VAE 2.3 GB；文本编码器与 H3 视频共用、不重复下）。
     `defaultFiles`：`transformer/model-%05d-of-00012.safetensors` ×12 + `vae/diffusion_pytorch_model.safetensors`
     + `pdd_fused_heads.safetensors`（6 步蒸馏的逐步输出头，约 12 MB）。
   - 新增 `H3_IMAGE_RESOLUTIONS`：8 个预设，4MP（2048² / 2688×1536 / 1536×2688）、
     8MP（2880² / 3840×2160 / 2160×3840）、16MP（4096² / 6272×2688），边长均为 32 的倍数
     （DiT 每 token 覆盖 32×32 像素）。
2. `ios_app/Sources/WorkspaceViews.swift`（CreateTabView）
   - 新增计算属性 `imageResolutionOptions`：选中 `minimax_h3_image` 时用 `H3_IMAGE_RESOLUTIONS`，
     否则用原 `IMAGE_RESOLUTIONS`；画幅菜单的 `ForEach` 改用该属性。其余 UI 不动。
3. `ios_app/Sources/IOSStudioViewModel.swift`（switchSelectedModel）
   - 切到 `minimax_h3_image` 时，若当前画幅不在 H3 预设内，默认落到 8MP 方图（2880×2880）；
     从 H3 切到其他生图模型时，若还挂着 H3 预设则回落 `IMAGE_RESOLUTIONS[0]`，
     避免把 4096×4096 之类尺寸发给 Qwen/Z-Image。

## build_ios_ipa.sh

**不用改**：脚本第 253 行以通配编译 `"${SCRIPT_DIR}"/Sources/*.swift`，且本次没有新增文件
（三处都是改现有文件）。已逐行确认。

## 自检

- Linux 无 swiftc：用 Python 对三个改动文件做了去字符串/去注释后的括号平衡巡检
  （{} / () / [] 全部平衡），并逐行复读了完整 diff。
- 已修正一处自查中发现的问题：初稿里 `× / · / —` 被写成字面 `\uXXXX` 转义
  （Swift 不支持该写法），已全部改回 UTF-8 字符，与现有文案一致。

## 未编译风险点（Mac 编译时重点看）

1. **defaultFiles 文件名必须与服务端分支的下载清单对账**（最高风险）：客户端文件名只是
   展示/存在性校验用，须与服务端 `setup`/目录清单逐个一致。若服务端最终用
   `transformer_diffusers/diffusion_pytorch_model-*` 布局或 VAE 文件名不同，
   合并时改 `LocalizationAndModels.swift` 里这一条的 `defaultFiles` 即可，不涉及其他代码。
   `pdd_fused_heads.safetensors` 是否在服务端下载清单内也要一并确认——不在清单内的话
   UI 上会恒显该文件缺失，应删掉这一项。
2. **approxSizeGB=68.6 的口径**：只算新增下载量（不含共用的 66.7 GB 编码器）。
   若服务端条目按含编码器的总占用（约 135 GB）写，客户端展示口径要与之统一。
3. **步数滑杆仍可拖动**：H3-Image 固定 6 步靠条目 `defaultSteps: 6` 在切换时落位，
   但用户仍可拖到别的值；最终以服务端为准（服务端应固定 6 步、忽略客户端步数或钳制）。
4. 16MP 预设（4096×4096 / 6272×2688）会原样进 payload 的 width/height，
   服务端 VAE 解码显存峰值需在 G4 上实测（方案里先以 8MP 验证）；客户端不做钳制。
5. `sparkles.rectangle.stack` 图标与 Custom HF 生图模型共用，SF Symbols 在目标 iOS 版本上
   已存在（现有代码已在用），风险低；编译后目视确认模型轮播条里的图标显示正常即可。
