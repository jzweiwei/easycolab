# MiniMax-H3-Image 服务端接入说明（分支 feat/h3-image-server）

Modified by jzweiwei (fork of wy51ai/easycolab, Apache-2.0), 2026-11-11.
`app.py` 文件头已加同款改动注明；`EasyColab_Server.ipynb` 的 cell 5 是
`app.py` 的逐字节内嵌副本（改前已验证 byte-identical），已同步回填，
cell 0 的模型列表也补了 MiniMax-H3-Image。

## 改动清单（app.py，行号以改后为准）

| # | 位置 | 改动 |
|---|------|------|
| 1 | 文件头 ~L5 | Apache-2.0 改动注明（fork / 日期 / 指向本文件） |
| 2 | `MINIMAX_H3_IMAGE_FILES` ~L1325 | 新增权重清单常量：`transformer/model-{00001..00012}-of-00012.safetensors` ×12 + `pdd_fused_heads.safetensors` + `vae/diffusion_pytorch_model.safetensors`（共 14 项）。小文件（config/index/processor）**不进清单**：`_find_existing_model_file()` 要求文件 >64KB，进清单会让完整性检查永远不通过；processor 在下载流程末尾单独获取（见 #5） |
| 3 | `MODEL_CATALOG["minimax_h3_image"]` ~L1352 | 新条目：`repo_id=MiniMaxAI/MiniMax-H3-Image`、`modality="image"`、`pipeline_arch="minimax_h3_image"`、`approx_size_gb=68.7`（仅新增下载量） |
| 4 | `inspect_and_resolve_hf_repo()` ~L2045 | 新增 H3-Image 识别分支，且**必须排在 `minimax_h3` 分支之前**：视频版匹配用子串 `"minimax-h3"`，会误吞 `"minimax-h3-image"` |
| 5 | `download_model_weights_core()` ~L3155 | 新增 `pipeline_arch == "minimax_h3_image"` 分支：下载末尾以 `ModelConfig(origin_file_pattern="processor/")` 拉取本仓 processor（照 `qwen_image_21` 写法） |
| 6 | `load_model_to_vram_core()` 显存阈值 ~L3964 | 新增分支：`required_free_gb = min(44, max(24, total-5))`（依据见下） |
| 7 | `load_model_to_vram_core()` 加载分支 ~L4103 | 新增分支（见下节）；另加便捷封装 `download_minimax_h3_image_weights_core()` / `load_minimax_h3_image_to_vram_core()`（~L4449/L4461） |
| 8 | `GenerateVideoRequest.size_preset` ~L6800 + `_h3_image_target_size()` ~L7240 | 新增可选字段 `size_preset`（`4MP`/`8MP`/`16MP`）；helper 按 req 宽高比换算到目标像素数并对齐 32 倍数，无预设时原样用 req 宽高。已离线单测：16MP+16:9 → 5472×3072（与 DiffSynth 文档表一致）、4MP 1:1 → 2048×2048 |
| 9 | `_run_async_generation_job()` 生成分支 ~L7434 | 新增分支：文生图（`task_mode` 非 `i2i_edit`）与改图（`i2i_edit` 时 first/last 图组装为 `edit_image` 列表，和 qwen_image_21 同款）；**强制 `num_inference_steps=6`、`cfg_scale=1.0`**，忽略客户端步数；输出 `minimax_h3_image_<task_mode>_<ts>_seed<n>.png` |
| 10 | OpenAI 兼容层 ~L8529 / L8778 / L8811 | `/v1/models` 增加 `MiniMaxAI/MiniMax-H3-Image`；`/v1/images/generations` 增加该模型的路由与调用（固定 6 步），503 提示文案同步 |

## DiffSynth API 依据（浅克隆 modelscope/DiffSynth-Studio 实测，非记忆）

- 管线：`diffsynth/pipelines/minimax_h3_image.py`
  - `MiniMaxH3ImagePipeline.from_pretrained(torch_dtype, device, model_configs, processor_config, vram_limit)`
  - `pipe.__call__(prompt, negative_prompt, cfg_scale=1.0, edit_image=None|PIL|list[PIL], height, width, seed, num_inference_steps=6, distilled=True, tiling=True, progress_bar_cmd)` → 返回单个 PIL Image；`edit_image` 非空即改图模式，提示词里以 `<Picture 1>` 引用参考图。
  - `from_pretrained` 内部按名取四件：`minimax_h3_text_encoder`、`minimax_h3_image_dit`、`minimax_h3_image_pdd_heads`、`minimax_h3_image_vae`；processor_config 下载后用 `AutoProcessor/AutoTokenizer.from_pretrained(path)`。
- 模型注册表：`diffsynth/configs/model_configs.py` 的 `minimax_h3_image_series`
  - DiT ← `transformer/model*.safetensors`（`MiniMaxH3ImageDiT`）
  - PDD 头 ← `pdd_fused_heads.safetensors`（`MiniMaxH3ImagePDDHeads`，实测仅 0.012 GB）
  - VAE ← `vae/diffusion_pytorch_model.safetensors`（`MiniMaxH3ImageVAE`）
  - 文本编码器在官方例中**直接用 H3 视频仓**：`ModelConfig(model_id="MiniMax/MiniMax-H3", origin_file_pattern="FL2VA/text_encoder/model*.safetensors")`（见 `docs/en/Model_Details/MiniMax-H3-Image.md` Quick Start 与低显存例 `examples/minimax_h3_image/model_inference_low_vram/MiniMax-H3-Image.py`）。
- 本实现的 ModelConfig 用法与 app.py 现有视频分支同款：以本地文件路径
  `ModelConfig(path=[...分片路径...], **vram_config)` 逐组件传入（分片靠 state-dict
  哈希/键名匹配注册表，与视频版 te/dit 的传法一致）。
- 卸载策略照低显存官方例：文本编码器 + VAE 用 app.py 通用 `vram_config`（磁盘流式）；
  DiT + PDD 头用与视频分支同款 `cpu_fast_vram_config`（BF16 常驻系统内存、逐层换入 GPU）。
  官方实测该策略在 H20 96GB 上 16MP 文生图+改图峰值约 38 GiB。
- 采样：蒸馏权重固定 6 步（一 步一个 PDD 输出头）、`distilled=True` 时步数必须为 6；
  `cfg_scale=1.0` 为发布行为（无 CFG），故生成分支强制这两项。

## 权重账（HF API 实测 MiniMaxAI/MiniMax-H3-Image，2026-11-11）

- `transformer/` 12 分片（`model-xxxxx-of-00012`）合计 ≈ 66.3 GB
- `pdd_fused_heads.safetensors` ≈ 0.012 GB；`vae/diffusion_pytorch_model.safetensors` ≈ 2.34 GB
- **新增下载 ≈ 68.7 GB**，落 `models/MiniMaxAI/MiniMax-H3-Image/`
- 文本编码器 14 分片（≈66.7 GB）**不下载**：运行时以
  `_resolve_and_stage_model_file("minimax_h3", "FL2VA/text_encoder/...")` 复用视频版；
  加载前逐片校验，缺片时直接报错并提示先下载 MiniMax-H3 视频权重（避免 DiffSynth 深处报晦涩错误）。
- 仓内另有 `transformer_diffusers/`、`vae_diffusers/`、`text_encoder/` 三套重复格式，**均不用**
  （全仓 204 GB 只取 DiffSynth 原生布局这一套）。

## 未实测风险点（本分支只做代码，未唤醒 Colab、未烧 CU）

1. **磁盘总账 ≈ 213 GB**：视频版约 144 GB + 生图新增约 69 GB（若走 Drive 持久化还另算）。
   Colab 实例盘/Drive 是否装得下，是首次唤醒时要验的第一件事；`download_model_weights_core`
   已有 Drive 空间不足自动改走本地 NVMe 的逻辑，但本地盘上限未验。
2. **16MP 的 VAE 解码显存峰值**：管线默认 `tiling=True`（分块解码、发布行为），峰值应受控；
   若实际运行时 tiling 被关或 16MP + 多参考图改图时峰值超预期，可能 OOM。
   对策预案：先用 8MP 预设验证，再上 16MP。
3. **ModelConfig(path=...) 的组件识别**：DiT 12 分片与 PDD/VAE/TE 分开以四个
   ModelConfig 传入，依赖 DiffSynth 按 state-dict 匹配注册表（与视频版同款传法，
   但生图组件组合未在真机验证）；若匹配失败会在 `from_pretrained` 的
   `fetch_model("minimax_h3_image_*")` 处报错，届时改为按官方例的
   `model_id + origin_file_pattern` 形式传入。
4. **CPU 常驻内存**：DiT BF16 常驻系统内存约 66 GB + 磁盘流式的编码器映射，
   G4 的 176 GB RAM 应足够；低 RAM 机型（A100 高 RAM 关）可能在加载阶段内存吃紧，
   届时把 DiT 也切回通用磁盘 `vram_config` 即可（一行改动）。
5. **客户端步数显示**：任务进度文案仍用 `req.num_inference_steps` 拼装提示文字，
   实际执行固定 6 步，文案数字可能与真实步数不一致（仅显示问题，不影响生成）。
6. 改图模式下参考图走 `first_frame_base64`/`last_frame_base64` 两个既有字段，
   最多 2 张；DiffSynth 支持最多 16 张参考图，如需扩展要动请求结构与客户端。

## 自检

- `python3 -m py_compile app.py` ✅ 通过
- `_h3_image_target_size()` AST 抽取离线单测 ✅（见 #8）
- ipynb 同步后断言 cell 5 == app.py ✅
