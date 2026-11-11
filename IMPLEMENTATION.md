# macOS 客户端：提示词灵感台移植 + MiniMax-H3-Image 入口

分支：`feat/mac-toolbar-image`（基于 `weiwei-custom` @ 5162d92）
本文件记录改动来源与未验证风险。所有移植段落均逐字取自旧魔改单文件
`EasyColabStudio.swift`（9534 行，Mac 本地 v1.0.2 时代版本），未整体搬运旧文件，
未回退上游 2026-11-10 的多文件重构。被改文件已按 Apache-2.0 §4(b) 在改动处加注
「weiwei-custom fork 移植/修改」。

## 1. 灵感台移植（旧 → 新）

| 旧单文件行号 | 内容 | 落点 |
|---|---|---|
| 554–769 | `CinemaCameraPreset` + `CINEMA_CAMERA_PRESETS`（6 款：原生/岩井俊二 85mm/王家卫 Cooke/迪金斯 IMAX/徕卡夜神/新海诚）、`ArtStylePreset` + `ART_STYLE_PRESETS`（10）、`CameraMotionPreset` + `CAMERA_MOTION_PRESETS`（8） | `macos_app/Sources/ModelsAndCatalogs.swift`，`PresetTemplate` 之前 |
| 771–817（结构定义部分） | `PresetTemplate` 的 `shortZh/shortEn/cameraId/universalScene` 字段 | 同文件：扩展上游 `PresetTemplate`，新增字段全部带默认值并加自定义 `init`，上游既有 7 条模板调用点零改动；新增计算属性 `shortName` |
| 820–1005（wf_* 段）+ 导演条 | WorldForge 12 组通用大师场景母版（`wf_*`，`universalScene: true`）+ `tpl_llm_cinema_director` | 同文件：追加进上游 `PRESET_TEMPLATES` 数组末尾（与上游 7 条无 id 冲突） |
| 1787–1796（状态部分） | 灵感台状态：`selectedCinemaCameraId/selectedArtStyleId/selectedCameraMotionId/showInspirationStudio/inspirationCategoryTab/isExpandingPromptWithQwen` | `macos_app/Sources/StudioViewModel.swift`，紧随 `musicPrompt`；默认值取 `raw_lens/none/none`（上游首条模板无 cameraId） |
| 3512–3770 | `activeCinemaCamera/activeArtStyle/activeCameraMotion`、`matchingTemplatesForActiveModality`、`applySceneTemplate`、`stripKnownSuffixes`、`selectCinemaCamera/selectArtStyle/selectCameraMotion`（点击替换提示词末尾机身/镜头/柔光镜/胶片后缀）、`pickRandomSceneInspiration`、`expandPromptWithQwen`（调用常驻 Qwen3.8-27B + 当前摄影机光学参数扩写） | `StudioViewModel.swift`，`switchSelectedModel` 之前 |
| 8262–8474（差异部分） | `promptComposerSection` 的灵感台形态：卡片标题（生图=「大师摄影机提示词」、ComfyUI=「电影级提示词与镜头灵感台」）、头部工具条（Qwen 导演扩写/随机灵感/复制/清空/展开收起镜头库）、工作台展开挂载点 | `macos_app/Sources/MainStudioView+Workspace.swift` 的现行 `promptComposerSection`：只叠加差异，未替换现行函数骨架；复制按钮改用上游已有的 `copyToPasteboard` 帮助函数（旧代码是直写 NSPasteboard） |
| 8475–8729 | `llmQuickInspirationRow`（LLM 快捷灵感芯片行）+ `cinemaInspirationWorkbench`（三 Tab：大师场景母版/电影摄影机与光学镜头/画风胶片&电影运镜） | 同文件，`promptEditor` 之前 |

未移植：旧文件约 5685 行处另一视图内的灵感芯片用法——该视图本身已被上游重构删除，
无对应落点；旧文件的云盘挂载相关改动按既定结论不移植。

## 2. MiniMax-H3-Image 入口

- `ModelsAndCatalogs.swift` 的 `OPEN_MODEL_CATALOG` 在 `qwen_image_21` 之后新增条目：
  - `id: "minimax_h3_image"`（与服务端另一分支 `app.py` MODEL_CATALOG 约定一致）
  - `repoId: "MiniMaxAI/MiniMax-H3-Image"`，`modality: .image`，`approxSizeGB: 68.6`
  - `defaultSteps: 6`（蒸馏 6 步、无 CFG；切换模型时现行逻辑自动写入 `inferenceSteps`）
  - 模式：`t2i` 文生图 + `i2i_edit` 指令改图（沿用现有生图模型的 TaskModeItem 写法）
  - `defaultFiles`：`transformer/diffusion_pytorch_model-%05d-of-00012.safetensors` ×12
    + `vae/diffusion_pytorch_model.safetensors`；文本编码器与 H3 视频版共用，
    不在客户端清单重复列出（服务端运行时指向视频那份）
  - 生成参数全部复用现行生图组件：提示词/反向提示词编辑器、`IMAGE_RESOLUTIONS`
    尺寸选择、`seed/randomizeSeed`、步数；生成载荷在 `StudioViewModel` 里按
    `.image` 模态统一组装（width/height/num_inference_steps/seed），无需新代码
- `MainStudioView+Workspace.swift` 的 `i2i_edit` 参考图区：把原本仅
  `qwen_image_21` 享有的「指令修图标题/副标题 + 第二张融合参考图」扩展到
  `minimax_h3_image`（多图融合编辑形态与 Qwen 一致）

## 3. 编译脚本

`macos_app/build_macos_app.sh` 已通配 `"${SCRIPT_DIR}"/Sources/*.swift`
（arm64 与 x86_64 两条 swiftc 命令均是），本次没有新增 Sources 文件，无需改脚本。

## 4. 自检与风险（未在 Mac 编译）

已做：逐文件括号/方括号/圆括号平衡巡检（剥离字符串与注释后计数一致）、
全 Sources 顶层符号重复定义检查（无重复）、`git diff --check` 干净、
插入连接处（模板数组拼接、目录条目、工作台挂载点）逐段复读。

风险点（需主代理在 Mac 编译时重点看）：
1. 本机 Linux 无 swiftc，以上只是静态巡检，不等于编译通过；类型推断类报错
   （如 `AnyView` 工具条、元组数组 `tabs` 的 `ForEach(..., id: \.0)`）只能在
   Mac 上暴露。灵感台 UI 段是从可运行的旧 App 逐字移植，风险相对低。
2. `cinemaInspirationWorkbench` 里保留了旧代码两处无害的恒等三元表达式
   （`"Theatermasks.fill".lowercased() == ... ? "paintpalette" : "paintpalette"` 等），
   与旧 App 行为一致，未做清理。
3. 灵感台 Tab0 标题沿用旧文案「大师场景母版 (17)」：现行过滤下视频类实际
   可见 15 条（12 通用 + 3 上游视频模板），文案数字与实际条数略有出入，
   属文案问题不影响功能，可后续顺手改成动态计数。
4. H3-Image 的 `defaultFiles` 文件名按 diffusers 布局推定
   （transformer 12 分片 + vae 单文件）；若服务端分支最终落盘布局不同
   （如沿用生图管线自定义命名），需同步改这份清单，否则客户端权重
   就绪状态显示会不准（不影响实际生成，服务端状态接口会覆盖）。
5. 尺寸：H3-Image 原生可达 4096×4096，但客户端复用现有
   `IMAGE_RESOLUTIONS`（最高 1536×1024）；要放开 4MP/8MP/16MP 档位，
   建议等服务端分支确认显存峰值（尤其 VAE 解码）后再单独加，避免其他
   生图模型误选超大尺寸。
6. 服务端 `minimax_h3_image` 条目在另一分支实现中；两分支合并后需做一次
   端到端冒烟（下载清单 id 对齐、文生图、改图各一次）。
