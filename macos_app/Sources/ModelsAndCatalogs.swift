import SwiftUI
import AppKit
import AVKit
import UniformTypeIdentifiers
import ObjectiveC.runtime

// MARK: - 多模型与多模态数据结构

enum ModelModality: String, Codable {
    case videoAudio = "video_audio"
    case video = "video"
    case image = "image"
    case llmVLM = "llm_vlm"
    case comfyUI = "comfyui"
}

struct TaskModeItem: Identifiable, Hashable {
    let id: String
    let titleZh: String
    let titleEn: String
    let subtitleZh: String
    let subtitleEn: String
    let icon: String

    var title: String { L(titleZh, titleEn) }
    var subtitle: String { L(subtitleZh, subtitleEn) }

    static func == (lhs: TaskModeItem, rhs: TaskModeItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct CustomHFModelDTO: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var repo_id: String
    var include_pattern: String?
    var modality: String?
    var pipeline_arch: String?
    var category: String?
    var approx_size_gb: Double?
    var is_custom: Bool?
}

struct OpenModelSpec: Identifiable, Hashable {
    let id: String
    let nameZh: String
    let nameEn: String
    let repoId: String
    let badgeZh: String
    let badgeEn: String
    let summaryZh: String
    let summaryEn: String
    let approxSizeGB: Double
    let icon: String
    let modality: ModelModality
    let defaultSteps: Double
    let modes: [TaskModeItem]
    let defaultFiles: [ModelFileItem]
    var includePattern: String = ""
    var isCustom: Bool = false

    var name: String { L(nameZh, nameEn) }
    var badge: String { L(badgeZh, badgeEn) }
    var summary: String { L(summaryZh, summaryEn) }

    static func == (lhs: OpenModelSpec, rhs: OpenModelSpec) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func fromCustomDTO(_ dto: CustomHFModelDTO) -> OpenModelSpec {
        let mod: ModelModality
        switch dto.modality {
        case "video_audio": mod = .videoAudio
        case "image": mod = .image
        default: mod = .llmVLM
        }
        let sizeGB = dto.approx_size_gb ?? 0.0
        let arch = (dto.pipeline_arch ?? "gguf").uppercased()
        let badgeZh = sizeGB > 0 ? String(format: "自定义 %@ · %.1f GB", arch, sizeGB) : "自定义 HF · \(arch)"
        let badgeEn = sizeGB > 0 ? String(format: "Custom %@ · %.1f GB", arch, sizeGB) : "Custom HF · \(arch)"
        let patDesc = (dto.include_pattern?.isEmpty == false) ? " (\(dto.include_pattern!))" : ""
        let summaryZh = dto.category ?? "自定义 HuggingFace 仓库 \(dto.repo_id)\(patDesc)"
        let summaryEn = "Custom HuggingFace repo \(dto.repo_id)\(patDesc)"
        let modes: [TaskModeItem]
        let iconName: String
        let defSteps: Double
        switch mod {
        case .videoAudio, .video:
            iconName = "film.stack"
            defSteps = 35
            modes = [
                TaskModeItem(id: "t2va", titleZh: "文生音视频", titleEn: "Text to Video+Audio", subtitleZh: "输入镜头与声音描述，同步生成视频与立体声音轨", subtitleEn: "Generate HD video and synchronized stereo audio from prompts", icon: "film"),
                TaskModeItem(id: "fl2va", titleZh: "首尾帧生视频", titleEn: "First/Last Frame to Video", subtitleZh: "上传首帧或尾帧参考图，精准控制起止画面与运镜过渡", subtitleEn: "Upload start or end keyframes to lock composition and camera transitions", icon: "photo.on.rectangle.angled")
            ]
        case .image:
            iconName = "sparkles.rectangle.stack"
            defSteps = 20
            modes = [
                TaskModeItem(id: "t2i", titleZh: "高清文生图", titleEn: "HD Text-to-Image", subtitleZh: "自定义 HuggingFace 图像生成管线", subtitleEn: "Custom HuggingFace image generation pipeline", icon: "photo.artframe"),
                TaskModeItem(id: "i2i_edit", titleZh: "图生图重绘", titleEn: "Image-to-Image Restyle", subtitleZh: "上传参考底图并调节重绘幅度，保留构图生成全新细节", subtitleEn: "Upload a reference image and adjust denoising strength to restyle", icon: "wand.and.rays")
            ]
        case .llmVLM, .comfyUI:
            iconName = "shippingbox.fill"
            defSteps = 20
            modes = [
                TaskModeItem(id: "chat", titleZh: "深度推理对话", titleEn: "Deep Reasoning Chat", subtitleZh: "自定义 HuggingFace 模型对话、长思维链推理与代码创作", subtitleEn: "Custom HuggingFace model chat, CoT reasoning & coding", icon: "bubble.left.and.bubble.right"),
                TaskModeItem(id: "vlm", titleZh: "图像视觉理解", titleEn: "Vision Understanding", subtitleZh: "拖入图片进行画面解析、OCR 识别或反推提示词", subtitleEn: "Drop images for scene analysis, OCR, or prompt reverse-engineering", icon: "eye"),
                TaskModeItem(id: "api", titleZh: "API 协议网关", titleEn: "API Protocol Gateway", subtitleZh: "提供 OpenAI (/v1) 与 Anthropic (/v1/messages) 双协议公网接口", subtitleEn: "Public dual-protocol gateway compatible with OpenAI (/v1) & Anthropic (/v1/messages)", icon: "network")
            ]
        }
        return OpenModelSpec(
            id: dto.id,
            nameZh: dto.name,
            nameEn: dto.name,
            repoId: dto.repo_id,
            badgeZh: badgeZh,
            badgeEn: badgeEn,
            summaryZh: summaryZh,
            summaryEn: summaryEn,
            approxSizeGB: sizeGB,
            icon: iconName,
            modality: mod,
            defaultSteps: defSteps,
            modes: modes,
            defaultFiles: [],
            includePattern: dto.include_pattern ?? "",
            isCustom: true
        )
    }
}

struct ModelFileItem: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var desc: String?
    var exists: Bool
    var size_gb: Double

    var localizedDesc: String? {
        guard let raw = desc, !raw.isEmpty else { return nil }
        return localizeModelFileDesc(raw)
    }
}

let OPEN_MODEL_CATALOG: [OpenModelSpec] = [
    OpenModelSpec(
        id: "minimax_h3",
        nameZh: "MiniMax-H3 (33B)",
        nameEn: "MiniMax-H3 (33B)",
        repoId: "MiniMaxAI/MiniMax-H3",
        badgeZh: "BF16 原生 · 134 GB",
        badgeEn: "Native BF16 · 134 GB",
        summaryZh: "全模态 BF16 原生满血精度同步生成高清视频与 32kHz 立体声音效、人声对白及配乐",
        summaryEn: "Full-modality native BF16 generation of HD video with synchronized 32kHz stereo SFX, dialogue & music",
        approxSizeGB: 134.1,
        icon: "film.stack",
        modality: .videoAudio,
        defaultSteps: 35,
        modes: [
            TaskModeItem(
                id: "t2va",
                titleZh: "文生音视频",
                titleEn: "Text to Video+Audio",
                subtitleZh: "输入镜头与声音描述，同步生成视频与立体声音轨",
                subtitleEn: "Generate HD video and synchronized stereo audio from scene & sound prompts",
                icon: "film"
            ),
            TaskModeItem(
                id: "fl2va",
                titleZh: "首尾帧生视频",
                titleEn: "First/Last Frame to Video",
                subtitleZh: "上传首帧或尾帧参考图，精准控制起止画面与运镜过渡",
                subtitleEn: "Upload start or end keyframes to lock composition and camera transitions",
                icon: "photo.on.rectangle.angled"
            )
        ],
        defaultFiles: (1...13).map { i in
            ModelFileItem(
                name: String(format: "FL2VA/transformer/model-%05d-of-00013.safetensors", i),
                desc: "DiT 音视频主干 BF16 \(i)/13",
                exists: false,
                size_gb: 0
            )
        } + (1...14).map { i in
            ModelFileItem(
                name: String(format: "FL2VA/text_encoder/model-%05d-of-00014.safetensors", i),
                desc: "多模态编码器 BF16 \(i)/14",
                exists: false,
                size_gb: 0
            )
        } + [
            ModelFileItem(name: "FL2VA/video_vae/source/model.safetensors", desc: "3D 视频 VAE BF16 (9.7 GB)", exists: false, size_gb: 0),
            ModelFileItem(name: "FL2VA/audio_vae/model.safetensors", desc: "32kHz 立体声 VAE BF16 (0.6 GB)", exists: false, size_gb: 0)
        ]
    ),
    OpenModelSpec(
        id: "comfyui_studio",
        nameZh: "ComfyUI 节点工作台",
        nameEn: "ComfyUI Node Studio",
        repoId: "comfyanonymous/ComfyUI",
        badgeZh: "节点视频创作 · 云盘软链持久化",
        badgeEn: "Node Video Studio · Drive Symlink Persist",
        summaryZh: "一键拉起云端 ComfyUI + Manager 全屏节点画布，自定义节点、视频权重与工作流自动软链持久化至 Google Drive",
        summaryEn: "1-click cloud ComfyUI + Manager fullscreen node canvas with Google Drive symlink persistence for custom nodes, weights & workflows",
        approxSizeGB: 0.0,
        icon: "point.3.connected.trianglepath.dotted",
        modality: .comfyUI,
        defaultSteps: 25,
        modes: [
            TaskModeItem(
                id: "comfy_canvas",
                titleZh: "全屏节点画布",
                titleEn: "Fullscreen Node Canvas",
                subtitleZh: "一键部署并跳转浏览器全屏节点画布，复用 G4 保活、折线监控与自动休眠",
                subtitleEn: "Deploy & open fullscreen canvas in browser with G4 keepalive, live telemetry & auto-sleep",
                icon: "macwindow.badge.plus"
            ),
            TaskModeItem(
                id: "comfy_assets",
                titleZh: "极速下权重与回传成片",
                titleEn: "Fast Weights & Pull Outputs",
                subtitleZh: "8 线程极速下载视频模型至云盘 models 目录，并将 output 成片一键回传 Mac",
                subtitleEn: "8-thread fast model download to Drive models folder & 1-click output pull to Mac",
                icon: "externaldrive.badge.icloud"
            )
        ],
        defaultFiles: []
    ),
    OpenModelSpec(
        id: "qwen38_27b",
        nameZh: "Qwen3.8-27B",
        nameEn: "Qwen3.8-27B",
        repoId: "Qwen/Qwen3.8-27B",
        badgeZh: "BF16 原生 · 51.8 GB",
        badgeEn: "Native BF16 · 51.8 GB",
        summaryZh: "Hugging Face 榜首开源多模态大模型（BF16 原生满血精度，支持最高 256K 上下文，需大显存实例）",
        summaryEn: "Top Hugging Face open multimodal LLM (full native BF16 precision, up to 256K context, high-VRAM GPU)",
        approxSizeGB: 51.8,
        icon: "brain",
        modality: .llmVLM,
        defaultSteps: 20,
        modes: [
            TaskModeItem(
                id: "chat",
                titleZh: "深度推理对话",
                titleEn: "Deep Reasoning Chat",
                subtitleZh: "支持长思维链推理、代码架构、复杂逻辑与分镜脚本创作",
                subtitleEn: "Long chain-of-thought reasoning, software architecture, logic & storyboard scripting",
                icon: "bubble.left.and.bubble.right"
            ),
            TaskModeItem(
                id: "vlm",
                titleZh: "图像视觉理解",
                titleEn: "Vision Understanding",
                subtitleZh: "拖入图片进行画面解析、OCR 识别或反推专业生图/生视频提示词",
                subtitleEn: "Drop images for scene analysis, OCR, or reverse-engineering image/video prompts",
                icon: "eye"
            ),
            TaskModeItem(
                id: "api",
                titleZh: "API 协议网关",
                titleEn: "API Protocol Gateway",
                subtitleZh: "提供 OpenAI (/v1) 与 Anthropic (/v1/messages) 双协议公网接口",
                subtitleEn: "Public dual-protocol gateway compatible with OpenAI (/v1) & Anthropic (/v1/messages)",
                icon: "network"
            )
        ],
        defaultFiles: (1...18).map { i in
            ModelFileItem(
                name: String(format: "model-%05d-of-00018.safetensors", i),
                desc: "权重分片 \(i)/18",
                exists: false,
                size_gb: 0
            )
        }
    ),
    OpenModelSpec(
        id: "qwen38_27b_gguf",
        nameZh: "Qwen3.8-27B-GGUF",
        nameEn: "Qwen3.8-27B-GGUF",
        repoId: "unsloth/Qwen3.8-27B-GGUF",
        badgeZh: "UD-Q4_K_M + MTP · 18.7 GB",
        badgeEn: "UD-Q4_K_M + MTP · 18.7 GB",
        summaryZh: "Unsloth 动态 4-bit 量化 + 原生 MTP 多词元投机解码加速，支持最高 256K 上下文与多模态视觉理解",
        summaryEn: "Unsloth dynamic 4-bit quantization + native MTP speculative decoding (~100 tok/s), up to 256K context & vision",
        approxSizeGB: 18.7,
        icon: "cpu",
        modality: .llmVLM,
        defaultSteps: 20,
        modes: [
            TaskModeItem(
                id: "chat",
                titleZh: "深度推理对话",
                titleEn: "Deep Reasoning Chat",
                subtitleZh: "UD-Q4_K_M + MTP 投机解码极速推理，支持长思维链、代码架构与超长上下文分析",
                subtitleEn: "Ultra-fast UD-Q4_K_M + MTP speculative decoding for CoT reasoning, coding & long-context analysis",
                icon: "bubble.left.and.bubble.right"
            ),
            TaskModeItem(
                id: "vlm",
                titleZh: "图像视觉理解",
                titleEn: "Vision Understanding",
                subtitleZh: "内置 mmproj-F16 视觉投影器，支持图片解析、OCR 与生图/生视频提示词反推",
                subtitleEn: "Built-in mmproj-F16 vision projector for image analysis, OCR & prompt reverse-engineering",
                icon: "eye"
            ),
            TaskModeItem(
                id: "api",
                titleZh: "API 协议网关",
                titleEn: "API Protocol Gateway",
                subtitleZh: "提供 OpenAI (/v1) 与 Anthropic (/v1/messages) 双协议公网接口",
                subtitleEn: "Public dual-protocol gateway compatible with OpenAI (/v1) & Anthropic (/v1/messages)",
                icon: "network"
            )
        ],
        defaultFiles: [
            ModelFileItem(name: "Qwen3.8-27B-UD-Q4_K_M.gguf", desc: "Unsloth UD-Q4_K_M 主模型 (16.5 GB)", exists: false, size_gb: 0),
            ModelFileItem(name: "mmproj-F16.gguf", desc: "多模态视觉投影器 (0.93 GB)", exists: false, size_gb: 0),
            ModelFileItem(name: "MTP/mtp-Qwen3.8-27B-Q4_0.gguf", desc: "Unsloth MTP 多词元投机解码头 (1.31 GB)", exists: false, size_gb: 0)
        ]
    ),
    OpenModelSpec(
        id: "qwen_image_21",
        nameZh: "Qwen-Image-2.1",
        nameEn: "Qwen-Image-2.1",
        repoId: "Qwen/Qwen-Image-2.1",
        badgeZh: "文生图与修图 · 30.9 GB",
        badgeEn: "Text-to-Image & Edit · 30.9 GB",
        summaryZh: "通义千问新一代旗舰图像生成与自然语言多图指令编辑模型",
        summaryEn: "Qwen flagship image generation & natural-language multi-image instruction editing model",
        approxSizeGB: 30.9,
        icon: "paintbrush.pointed",
        modality: .image,
        defaultSteps: 40,
        modes: [
            TaskModeItem(
                id: "t2i",
                titleZh: "高清文生图",
                titleEn: "HD Text-to-Image",
                subtitleZh: "复杂构图、精准中英文排版与高质感摄影/插画生成",
                subtitleEn: "Complex composition, accurate bilingual typography & high-fidelity photography/illustration",
                icon: "photo.artframe"
            ),
            TaskModeItem(
                id: "i2i_edit",
                titleZh: "多图指令修图",
                titleEn: "Multi-Image Instruction Edit",
                subtitleZh: "上传 1~2 张原图，用自然语言指令改局部、换背景或融合主体",
                subtitleEn: "Upload 1–2 source images to edit regions, swap backgrounds, or fuse subjects via natural language",
                icon: "wand.and.rays"
            )
        ],
        defaultFiles: [
            ModelFileItem(name: "transformer/diffusion_pytorch_model-00001-of-00002.safetensors", desc: "DiT 1/2", exists: false, size_gb: 0),
            ModelFileItem(name: "transformer/diffusion_pytorch_model-00002-of-00002.safetensors", desc: "DiT 2/2", exists: false, size_gb: 0),
            ModelFileItem(name: "text_encoder/model-00001-of-00004.safetensors", desc: "编码器 1/4", exists: false, size_gb: 0),
            ModelFileItem(name: "text_encoder/model-00002-of-00004.safetensors", desc: "编码器 2/4", exists: false, size_gb: 0),
            ModelFileItem(name: "text_encoder/model-00003-of-00004.safetensors", desc: "编码器 3/4", exists: false, size_gb: 0),
            ModelFileItem(name: "text_encoder/model-00004-of-00004.safetensors", desc: "编码器 4/4", exists: false, size_gb: 0),
            ModelFileItem(name: "vae/diffusion_pytorch_model.safetensors", desc: "图像 VAE", exists: false, size_gb: 0)
        ]
    ),
    // weiwei-custom fork 新增：MiniMax-H3-Image（id 与服务端 app.py MODEL_CATALOG 约定一致）
    OpenModelSpec(
        id: "minimax_h3_image",
        nameZh: "MiniMax-H3-Image",
        nameEn: "MiniMax-H3-Image",
        repoId: "MiniMaxAI/MiniMax-H3-Image",
        badgeZh: "文生图与改图 · 约 68.6 GB（复用 H3 视频编码器）",
        badgeEn: "Text-to-Image & Edit · ~68.6 GB (shares H3 video encoder)",
        summaryZh: "MiniMax H3 家族生图版：文生图与指令改图合一，蒸馏 6 步无 CFG，原生高像素直出；文本编码器与 MiniMax-H3 视频版共用，服务端只额外下载 DiT 与 VAE",
        summaryEn: "Image member of the MiniMax H3 family: unified text-to-image & instruction editing, distilled 6-step no-CFG, native high-resolution output; shares its text encoder with MiniMax-H3 video, so the server only downloads the DiT and VAE",
        approxSizeGB: 68.6,
        icon: "photo.artframe",
        modality: .image,
        defaultSteps: 6,
        modes: [
            TaskModeItem(
                id: "t2i",
                titleZh: "高清文生图",
                titleEn: "HD Text-to-Image",
                subtitleZh: "原生高像素直出（最高 4096×4096），6 步蒸馏极速生成",
                subtitleEn: "Native high-res output (up to 4096x4096), distilled 6-step fast generation",
                icon: "photo.artframe"
            ),
            TaskModeItem(
                id: "i2i_edit",
                titleZh: "指令改图",
                titleEn: "Instruction Image Edit",
                subtitleZh: "上传参考原图，用自然语言指令改局部、换背景或重绘风格",
                subtitleEn: "Upload a reference image and edit regions, swap backgrounds, or restyle via natural language",
                icon: "wand.and.rays"
            )
        ],
        defaultFiles: (1...12).map { i in
            ModelFileItem(
                name: String(format: "transformer/model-%05d-of-00012.safetensors", i),
                desc: "生图 DiT 主干 BF16 \(i)/12",
                exists: false,
                size_gb: 0
            )
        } + [
            ModelFileItem(name: "vae/diffusion_pytorch_model.safetensors", desc: "图像 VAE (2.3 GB)", exists: false, size_gb: 0),
            ModelFileItem(name: "pdd_fused_heads.safetensors", desc: "6 步蒸馏逐步输出头 (12 MB)", exists: false, size_gb: 0)
        ]
    ),
    OpenModelSpec(
        id: "z_image_turbo",
        nameZh: "Z-Image-Turbo",
        nameEn: "Z-Image-Turbo",
        repoId: "Tongyi-MAI/Z-Image-Turbo",
        badgeZh: "8步极速生图 · 30.6 GB",
        badgeEn: "8-Step Turbo Image · 30.6 GB",
        summaryZh: "Hugging Face 高人气 8 步蒸馏极速写实摄影与中英文海报生图模型",
        summaryEn: "Popular Hugging Face 8-step distilled model for ultra-fast photorealism & bilingual poster design",
        approxSizeGB: 30.6,
        icon: "bolt.square",
        modality: .image,
        defaultSteps: 8,
        modes: [
            TaskModeItem(
                id: "t2i",
                titleZh: "8 步极速文生图",
                titleEn: "8-Step Fast Text-to-Image",
                subtitleZh: "仅需 8 步采样，秒级输出商业级人像摄影与中英文排版画面",
                subtitleEn: "Commercial-grade portrait photography & bilingual poster typography in just 8 steps",
                icon: "bolt"
            ),
            TaskModeItem(
                id: "i2i_edit",
                titleZh: "图生图风格重绘",
                titleEn: "Image-to-Image Restyle",
                subtitleZh: "上传参考底图并调节重绘幅度，保留构图生成全新细节",
                subtitleEn: "Upload a reference image and adjust denoising strength to restyle while preserving layout",
                icon: "square.on.square"
            )
        ],
        defaultFiles: [
            ModelFileItem(name: "transformer/diffusion_pytorch_model-00001-of-00003.safetensors", desc: "DiT 1/3", exists: false, size_gb: 0),
            ModelFileItem(name: "transformer/diffusion_pytorch_model-00002-of-00003.safetensors", desc: "DiT 2/3", exists: false, size_gb: 0),
            ModelFileItem(name: "transformer/diffusion_pytorch_model-00003-of-00003.safetensors", desc: "DiT 3/3", exists: false, size_gb: 0),
            ModelFileItem(name: "text_encoder/model-00001-of-00003.safetensors", desc: "编码器 1/3", exists: false, size_gb: 0),
            ModelFileItem(name: "text_encoder/model-00002-of-00003.safetensors", desc: "编码器 2/3", exists: false, size_gb: 0),
            ModelFileItem(name: "text_encoder/model-00003-of-00003.safetensors", desc: "编码器 3/3", exists: false, size_gb: 0),
            ModelFileItem(name: "vae/diffusion_pytorch_model.safetensors", desc: "图像 VAE", exists: false, size_gb: 0)
        ]
    )
]

struct ResolutionOption: Identifiable, Hashable {
    let id: String
    let labelZh: String
    let labelEn: String
    let width: Int
    let height: Int

    var label: String { L(labelZh, labelEn) }

    static func == (lhs: ResolutionOption, rhs: ResolutionOption) -> Bool {
        lhs.id == rhs.id && lhs.width == rhs.width && lhs.height == rhs.height
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(width)
        hasher.combine(height)
    }
}

let VIDEO_RESOLUTIONS: [ResolutionOption] = [
    ResolutionOption(id: "v_832_480", labelZh: "832 × 480 (16:9 横屏标准 · 推荐)", labelEn: "832 × 480 (16:9 Landscape · Recommended)", width: 832, height: 480),
    ResolutionOption(id: "v_480_832", labelZh: "480 × 832 (9:16 竖屏短视频)", labelEn: "480 × 832 (9:16 Vertical Short)", width: 480, height: 832),
    ResolutionOption(id: "v_1280_720", labelZh: "1280 × 720 (16:9 720P 高清)", labelEn: "1280 × 720 (16:9 720P HD)", width: 1280, height: 720),
    ResolutionOption(id: "v_720_1280", labelZh: "720 × 1280 (9:16 720P 竖屏)", labelEn: "720 × 1280 (9:16 720P Vertical)", width: 720, height: 1280),
    ResolutionOption(id: "v_640_640", labelZh: "640 × 640 (1:1 方形)", labelEn: "640 × 640 (1:1 Square)", width: 640, height: 640)
]

let IMAGE_RESOLUTIONS: [ResolutionOption] = [
    ResolutionOption(id: "i_1024_1024", labelZh: "1024 × 1024 (1:1 超清方图 · 推荐)", labelEn: "1024 × 1024 (1:1 Square HD · Recommended)", width: 1024, height: 1024),
    ResolutionOption(id: "i_1344_768", labelZh: "1344 × 768 (16:9 电影横幅)", labelEn: "1344 × 768 (16:9 Cinematic Widescreen)", width: 1344, height: 768),
    ResolutionOption(id: "i_768_1344", labelZh: "768 × 1344 (9:16 竖版海报)", labelEn: "768 × 1344 (9:16 Vertical Poster)", width: 768, height: 1344),
    ResolutionOption(id: "i_1536_1024", labelZh: "1536 × 1024 (3:2 单反摄影)", labelEn: "1536 × 1024 (3:2 DSLR Photo)", width: 1536, height: 1024)
]

// MiniMax-H3-Image native output presets (4MP / 8MP / 16MP tiers, all dimensions multiples of 32)
let H3_IMAGE_RESOLUTIONS: [ResolutionOption] = [
    ResolutionOption(id: "h3_4mp_2048_2048", labelZh: "2048 × 2048 (1:1 · 4MP 方图)", labelEn: "2048 × 2048 (1:1 · 4MP Square)", width: 2048, height: 2048),
    ResolutionOption(id: "h3_4mp_2688_1536", labelZh: "2688 × 1536 (16:9 · 4MP 横幅)", labelEn: "2688 × 1536 (16:9 · 4MP Widescreen)", width: 2688, height: 1536),
    ResolutionOption(id: "h3_4mp_1536_2688", labelZh: "1536 × 2688 (9:16 · 4MP 竖幅)", labelEn: "1536 × 2688 (9:16 · 4MP Portrait)", width: 1536, height: 2688),
    ResolutionOption(id: "h3_8mp_2880_2880", labelZh: "2880 × 2880 (1:1 · 8MP 方图 · 推荐)", labelEn: "2880 × 2880 (1:1 · 8MP Square · Recommended)", width: 2880, height: 2880),
    ResolutionOption(id: "h3_8mp_3840_2160", labelZh: "3840 × 2160 (16:9 · 8MP 4K 横幅)", labelEn: "3840 × 2160 (16:9 · 8MP 4K Widescreen)", width: 3840, height: 2160),
    ResolutionOption(id: "h3_8mp_2160_3840", labelZh: "2160 × 3840 (9:16 · 8MP 4K 竖幅)", labelEn: "2160 × 3840 (9:16 · 8MP 4K Portrait)", width: 2160, height: 3840),
    ResolutionOption(id: "h3_16mp_4096_4096", labelZh: "4096 × 4096 (1:1 · 16MP 极限方图)", labelEn: "4096 × 4096 (1:1 · 16MP Max Square)", width: 4096, height: 4096),
    ResolutionOption(id: "h3_16mp_6272_2688", labelZh: "6272 × 2688 (21:9 · 16MP 电影超宽幅)", labelEn: "6272 × 2688 (21:9 · 16MP Cinematic Ultrawide)", width: 6272, height: 2688)
]

// MARK: - 提示词灵感台预设（weiwei-custom fork 移植自旧魔改单文件 EasyColabStudio.swift 第 554–769 行）

struct CinemaCameraPreset: Identifiable, Hashable {
    let id: String
    let shortZh: String
    let shortEn: String
    let nameZh: String
    let nameEn: String
    let sensor: String
    let lens: String
    let filter: String
    let suffix: String

    var shortName: String { L(shortZh, shortEn) }
    var name: String { L(nameZh, nameEn) }
}

let CINEMA_CAMERA_PRESETS: [CinemaCameraPreset] = [
    CinemaCameraPreset(
        id: "raw_lens",
        shortZh: "🎞️ 原生直出",
        shortEn: "🎞️ Raw Lens",
        nameZh: "🎞️ 原生直出 · 不附加光学后缀 (Raw Unfiltered)",
        nameEn: "🎞️ Raw Unfiltered · No Optical Suffix",
        sensor: "Native Pipeline",
        lens: "Direct Prompt",
        filter: "None",
        suffix: ""
    ),
    CinemaCameraPreset(
        id: "iwai_85mm_f12",
        shortZh: "🌸 岩井俊二 85mm f/1.2L",
        shortEn: "🌸 Iwai 85mm f/1.2L",
        nameZh: "🌸 岩井俊二 · 逆光柔焦人像机 (ARRI Alexa 65 + Canon FD 85mm f/1.2L)",
        nameEn: "🌸 Iwai Shunji · Backlit Soft Portrait (ARRI Alexa 65 + Canon FD 85mm f/1.2L)",
        sensor: "ARRI Alexa 65 (Open Gate 6.5K)",
        lens: "Canon FD 85mm f/1.2L Aspherical (Wide Open)",
        filter: "Tiffen Black Pro-Mist 1/4 + Kodak Portra 400",
        suffix: ", Captured on ARRI Alexa 65 paired with vintage Canon FD 85mm f/1.2L lens wide open at f/1.2, Tiffen Black Pro-Mist 1/4 soft filter, warm golden hour backlighting creating a glowing amber rim light around hair, translucent porcelain skin with delicate rosy blush and subsurface scattering, ultra-shallow depth of field, creamy dreamy bokeh, soft Tyndall light rays, Kodak Portra 400 film aesthetic, 8K masterpiece cinematography"
    ),
    CinemaCameraPreset(
        id: "wong_kar_wai_anamorphic",
        shortZh: "🌧️ 王家卫 Cooke 40mm",
        shortEn: "🌧️ Wong Kar-wai Cooke 40mm",
        nameZh: "🌧️ 王家卫 × 杜可风 · 变形宽银幕夜雨机 (Alexa Mini LF + Cooke Anamorphic 40mm T2.0)",
        nameEn: "🌧️ Wong Kar-wai × Doyle · Anamorphic Neon (Alexa Mini LF + Cooke 40mm T2.0)",
        sensor: "ARRI Alexa Mini LF (2.39:1 Anamorphic)",
        lens: "Cooke Anamorphic/i SF 40mm T2.0 (Special Flare)",
        filter: "Kodak Vision3 500T 5219 + Warm Halation",
        suffix: ", Wong Kar-wai and Christopher Doyle aesthetic, shot on ARRI Alexa Mini LF with vintage Cooke Anamorphic/i 40mm T2.0 lens, creamy oval anamorphic bokeh, subtle horizontal blue-and-gold anamorphic lens flare streaks, rich emerald and crimson-amber neon color grading, 35mm Kodak Vision3 500T film grain, 8K masterpiece"
    ),
    CinemaCameraPreset(
        id: "deakins_imax_65mm",
        shortZh: "☀️ 迪金斯 IMAX 65mm",
        shortEn: "☀️ Deakins IMAX 65mm",
        nameZh: "☀️ 罗杰·迪金斯 · 史诗丁达尔神光机 (IMAX 65mm + Panavision Primo 70)",
        nameEn: "☀️ Roger Deakins · Epic Volumetric God Rays (IMAX 65mm + Panavision Primo 70)",
        sensor: "IMAX 15/70mm Film Camera",
        lens: "Panavision Primo 70 50mm T1.9",
        filter: "Natural Volumetric Atmosphere + ACEScct",
        suffix: ", Roger Deakins Academy Award cinematography, shot on IMAX 65mm film camera with Panavision Primo 70 50mm T1.9 lens, breathtaking volumetric god rays and Tyndall light shafts, chiaroscuro golden sculptural lighting, ultra-wide dynamic range, razor-sharp micro-contrast, 8K IMAX theatrical still"
    ),
    CinemaCameraPreset(
        id: "leica_noctilux_f095",
        shortZh: "💎 徕卡夜神 50mm f/0.95",
        shortEn: "💎 Leica Noctilux f/0.95",
        nameZh: "💎 徕卡夜神 · 空气感刀锐奶化机 (Sony Venice 2 8K + Leica Noctilux 50mm f/0.95)",
        nameEn: "💎 Leica Noctilux · Creamy 3D Pop Portrait (Sony Venice 2 8K + 50mm f/0.95)",
        sensor: "Sony Venice 2 8.6K Full-Frame",
        lens: "Leica Noctilux-M 50mm f/0.95 ASPH",
        filter: "Schneider Hollywood Black Magic 1/8",
        suffix: ", Shot on Sony Venice 2 8K full-frame cinema camera paired with Leica Noctilux-M 50mm f/0.95 ASPH wide open at f/0.95, signature Leica 3D pop and painterly swirly cat-eye bokeh, luminous catchlights in eyes, flawless natural skin micro-texture with warm subsurface glow, 8K editorial cinema portrait"
    ),
    CinemaCameraPreset(
        id: "shinkai_twilight_panavision",
        shortZh: "🌌 新海诚暮光 24mm T1.4",
        shortEn: "🌌 Shinkai Twilight 24mm",
        nameZh: "🌌 新海诚 · 暮光流云超广角机 (Panavision DXL2 + Primo 24mm T1.4)",
        nameEn: "🌌 Makoto Shinkai · Twilight Wide-Angle (Panavision DXL2 + Primo 24mm T1.4)",
        sensor: "Panavision Millennium DXL2 8K Monstro",
        lens: "Panavision Primo Artiste 24mm T1.4",
        filter: "Twilight Magic Hour Diffusion",
        suffix: ", Makoto Shinkai twilight magic hour aesthetic meets live-action Panavision Millennium DXL2 8K cinema camera, 24mm T1.4 wide-angle cinema lens, luminous violet-gold-cobalt cumulus clouds, shimmering lens reflection, ethereal atmospheric perspective, ultra-vivid HDR color harmony, 8K masterpiece"
    )
]

struct ArtStylePreset: Identifiable, Hashable {
    let id: String
    let nameZh: String
    let nameEn: String
    let suffixZh: String
    let suffixEn: String

    var name: String { L(nameZh, nameEn) }
    var suffix: String { L(suffixZh, suffixEn) }
}

let ART_STYLE_PRESETS: [ArtStylePreset] = [
    ArtStylePreset(id: "none", nameZh: "🎞️ 原生直出", nameEn: "🎞️ Raw Style", suffixZh: "", suffixEn: ""),
    ArtStylePreset(
        id: "iwai_cinema",
        nameZh: "🌸 岩井俊二柔焦胶片",
        nameEn: "🌸 Iwai Soft Portra 400",
        suffixZh: "，Captured on ARRI Alexa 65 paired with vintage Canon FD 85mm f/1.2L lens wide open at f/1.2, Tiffen Black Pro-Mist 1/4 soft filter, warm golden hour backlighting creating a glowing amber rim light, translucent porcelain skin with delicate rosy blush and subsurface scattering, ultra-shallow depth of field, creamy dreamy bokeh, Kodak Portra 400 film aesthetic, 8K masterpiece",
        suffixEn: ", Captured on ARRI Alexa 65 paired with vintage Canon FD 85mm f/1.2L lens wide open at f/1.2, Tiffen Black Pro-Mist 1/4 soft filter, warm golden hour backlighting creating a glowing amber rim light, translucent porcelain skin with delicate rosy blush and subsurface scattering, ultra-shallow depth of field, creamy dreamy bokeh, Kodak Portra 400 film aesthetic, 8K masterpiece"
    ),
    ArtStylePreset(
        id: "wkw_anamorphic",
        nameZh: "🌧️ 王家卫霓虹宽银幕",
        nameEn: "🌧️ WKW Anamorphic Neon",
        suffixZh: "，Wong Kar-wai and Christopher Doyle aesthetic, shot on ARRI Alexa Mini LF with vintage Cooke Anamorphic/i 40mm T2.0 lens, creamy oval anamorphic bokeh, horizontal blue-and-gold lens flare, rich emerald and crimson-amber color grading, 35mm Kodak Vision3 500T film grain, 8K masterpiece",
        suffixEn: ", Wong Kar-wai and Christopher Doyle aesthetic, shot on ARRI Alexa Mini LF with vintage Cooke Anamorphic/i 40mm T2.0 lens, creamy oval anamorphic bokeh, horizontal blue-and-gold lens flare, rich emerald and crimson-amber color grading, 35mm Kodak Vision3 500T film grain, 8K masterpiece"
    ),
    ArtStylePreset(
        id: "leica_noctilux",
        nameZh: "💎 徕卡夜神空气人像",
        nameEn: "💎 Leica Noctilux Portrait",
        suffixZh: "，Shot on Sony Venice 2 8K paired with Leica Noctilux-M 50mm f/0.95 ASPH wide open, signature Leica 3D pop and swirly cat-eye bokeh, luminous catchlights, flawless natural skin micro-texture with warm subsurface glow, 8K cinema portrait",
        suffixEn: ", Shot on Sony Venice 2 8K paired with Leica Noctilux-M 50mm f/0.95 ASPH wide open, signature Leica 3D pop and swirly cat-eye bokeh, luminous catchlights, flawless natural skin micro-texture with warm subsurface glow, 8K cinema portrait"
    ),
    ArtStylePreset(
        id: "cinematic",
        nameZh: "🎬 迪金斯 IMAX 电影感",
        nameEn: "🎬 Deakins IMAX 65mm",
        suffixZh: "，Roger Deakins Academy Award cinematography, shot on IMAX 65mm film camera with Panavision Primo 70 50mm T1.9 lens, volumetric god rays, HDR cinematic color grading, 8K theatrical masterpiece",
        suffixEn: ", Roger Deakins Academy Award cinematography, shot on IMAX 65mm film camera with Panavision Primo 70 50mm T1.9 lens, volumetric god rays, HDR cinematic color grading, 8K theatrical masterpiece"
    ),
    ArtStylePreset(
        id: "ghibli",
        nameZh: "🌿 吉卜力手绘动画",
        nameEn: "🌿 Studio Ghibli Watercolor",
        suffixZh: "，吉卜力工作室手绘动画美术风格，水彩水粉质感背景，柔和明亮的色彩，宫崎骏电影截图级别，Studio Ghibli hand-painted anime art style, lush watercolor background",
        suffixEn: ", Studio Ghibli hand-painted anime art style, lush watercolor and gouache background texture, warm nostalgic palette, Hayao Miyazaki theatrical film frame"
    ),
    ArtStylePreset(
        id: "pixar",
        nameZh: "🧸 皮克斯 3D 动画",
        nameEn: "🧸 Pixar 3D Animation",
        suffixZh: "，皮克斯迪士尼风格3D动画电影画面，柔和全局光照，次表面散射材质，精致细节，Pixar and Disney 3D feature animation render, soft global illumination",
        suffixEn: ", Pixar and Disney 3D feature animation style, soft global illumination, expressive character design, rich subsurface scattering, 8K theatrical render"
    ),
    ArtStylePreset(
        id: "ue5",
        nameZh: "⚔️ 虚幻5 次世代 CG",
        nameEn: "⚔️ Unreal Engine 5 CG",
        suffixZh: "，虚幻引擎5实时渲染，次世代3A游戏CG，Lumen全局光照与光线追踪体积雾，史诗级场景，Unreal Engine 5 Lumen ray-tracing cinematic CG",
        suffixEn: ", Unreal Engine 5 cinematic CG render, Lumen global illumination, ray-traced reflections, volumetric fog, AAA next-gen masterpiece"
    ),
    ArtStylePreset(
        id: "portrait",
        nameZh: "📸 哈苏中画幅高定",
        nameEn: "📸 Hasselblad Editorial",
        suffixZh: "，顶级商业影楼人像摄影，哈苏 H6D-100c 中画幅，HC 100mm f/2.2，柔和伦勃朗轮廓光，真实通透皮肤肌理，Vogue 杂志封面级",
        suffixEn: ", High-fashion editorial portrait photography, Hasselblad H6D-100c medium format, HC 100mm f/2.2 lens, soft Rembrandt rim lighting, natural skin micro-texture, Vogue cover masterpiece"
    ),
    ArtStylePreset(
        id: "ink",
        nameZh: "🖌️ 东方水墨流金",
        nameEn: "🖌️ Chinese Ink & Gold",
        suffixZh: "，中国传统水墨设色结合盛唐流金工笔美学，留白意境，宣纸肌理，东方诗意电影感，poetic Chinese ink-wash and gold leaf masterpiece",
        suffixEn: ", Traditional Chinese ink-wash painting fused with Tang Dynasty gold-leaf fine brushwork, poetic negative space, Xuan paper texture, ethereal Eastern cinema aesthetic"
    )
]

struct CameraMotionPreset: Identifiable, Hashable {
    let id: String
    let nameZh: String
    let nameEn: String
    let suffix: String

    var name: String { L(nameZh, nameEn) }
}

let CAMERA_MOTION_PRESETS: [CameraMotionPreset] = [
    CameraMotionPreset(id: "none", nameZh: "🎯 默认运镜", nameEn: "🎯 Default Motion", suffix: ""),
    CameraMotionPreset(
        id: "flythrough",
        nameZh: "🚀 单点透视纵深穿行",
        nameEn: "🚀 One-Point Flythrough",
        suffix: ", smooth continuous forward dolly-in camera movement gliding steadily down the central one-point perspective axis with strong 3D parallax depth, 24fps gimbal stabilization"
    ),
    CameraMotionPreset(
        id: "orbit",
        nameZh: "🔄 环绕凝视推镜",
        nameEn: "🔄 Orbital Tracking",
        suffix: ", smooth orbital tracking shot circling gracefully around the main subject while slowly pushing in with shallow depth of field"
    ),
    CameraMotionPreset(
        id: "dolly_zoom",
        nameZh: "🎬 希区柯克抽拉变焦",
        nameEn: "🎬 Dolly Zoom Push-Pull",
        suffix: ", dramatic cinematic dolly zoom push-pull camera trajectory smoothly pulling back to reveal the grand environment and pushing forward toward the focal subject"
    ),
    CameraMotionPreset(
        id: "crane_rise",
        nameZh: "🦅 摇臂升空俯瞰",
        nameEn: "🦅 Crane Rise Reveal",
        suffix: ", majestic cinematic crane shot rising vertically from low angle to reveal the vast panoramic horizon with volumetric lighting"
    ),
    CameraMotionPreset(
        id: "fpv_dive",
        nameZh: "⚡ FPV 穿越机俯冲",
        nameEn: "⚡ FPV Drone Dive",
        suffix: ", dynamic high-speed FPV drone dive weaving smoothly through foreground structures with natural motion blur and exhilarating depth"
    ),
    CameraMotionPreset(
        id: "slow_track",
        nameZh: "🌊 升格慢镜横移跟拍",
        nameEn: "🌊 Slow-Mo Lateral Track",
        suffix: ", fluid Steadicam lateral tracking shot gliding parallel to the subject in dreamy slow-motion cadence, floating particles and hair movement"
    ),
    CameraMotionPreset(
        id: "static_master",
        nameZh: "🖼️ 大师固定长镜头",
        nameEn: "🖼️ Static Master Shot",
        suffix: ", locked-off tripod cinema master shot with subtle natural subject motion, gentle breeze, and shifting volumetric light rays"
    )
]

// weiwei-custom fork 修改：为提示词灵感台扩展 PresetTemplate（新增 shortZh/shortEn/cameraId/universalScene，
// 均带默认值，上游既有模板调用点无需改动）；灵感台数据结构移植自旧魔改单文件 EasyColabStudio.swift。
struct PresetTemplate: Identifiable {
    let id: String
    let category: ModelModality
    let nameZh: String
    let nameEn: String
    let visualZh: String
    let visualEn: String
    let soundscape: String
    let music: String
    let shortZh: String
    let shortEn: String
    let cameraId: String
    let universalScene: Bool

    init(
        id: String,
        category: ModelModality,
        nameZh: String,
        nameEn: String,
        visualZh: String,
        visualEn: String,
        soundscape: String = "",
        music: String = "",
        shortZh: String = "",
        shortEn: String = "",
        cameraId: String = "raw_lens",
        universalScene: Bool = false
    ) {
        self.id = id
        self.category = category
        self.shortZh = shortZh.isEmpty ? nameZh : shortZh
        self.shortEn = shortEn.isEmpty ? nameEn : shortEn
        self.nameZh = nameZh
        self.nameEn = nameEn
        self.visualZh = visualZh
        self.visualEn = visualEn
        self.soundscape = soundscape
        self.music = music
        self.cameraId = cameraId
        self.universalScene = universalScene
    }

    var shortName: String { L(shortZh, shortEn) }
    var name: String { L(nameZh, nameEn) }
    var visual: String { L(visualZh, visualEn) }
}

let PRESET_TEMPLATES: [PresetTemplate] = [
    PresetTemplate(
        id: "tpl_shinkai_train",
        category: .videoAudio,
        nameZh: "[动漫] 新海诚风 · 盛夏樱花铁道口",
        nameEn: "[Anime] Makoto Shinkai · Cherry Blossom Railway",
        visualZh: "Masterpiece Makoto Shinkai anime style, 2D cel-shaded animation. A teenage girl in a Japanese sailor school uniform standing at a sunlit railway crossing in late spring. A green commuter train speeds past in front of her, creating a strong gust of wind that blows her long black hair and a flurry of pink cherry blossom petals across the frame. Dramatic lens flare, glowing cumulous clouds in a deep blue sky, vibrant cinematic lighting, smooth 24fps keyframe animation.",
        visualEn: "Masterpiece Makoto Shinkai anime style, 2D cel-shaded animation. A teenage girl in a Japanese sailor school uniform standing at a sunlit railway crossing in late spring. A green commuter train speeds past in front of her, creating a strong gust of wind that blows her long black hair and a flurry of pink cherry blossom petals across the frame. Dramatic lens flare, glowing cumulous clouds in a deep blue sky, vibrant cinematic lighting, smooth 24fps keyframe animation.",
        soundscape: "Metallic clacking of train wheels on railway tracks, rhythmic dinging of the railroad crossing warning bell, warm spring wind rustling through leaves, a soft gasp from the girl.",
        music: "Emotional and nostalgic solo piano melody joined by warm acoustic guitar and soaring cinematic strings."
    ),
    PresetTemplate(
        id: "tpl_ufotable_duel",
        category: .videoAudio,
        nameZh: "[动漫] 飞碟社风 · 苍蓝雷光剑术对决",
        nameEn: "[Anime] Ufotable Sakuga · Azure Lightning Sword Duel",
        visualZh: "High-budget ufotable anime action sakuga, dynamic fast-paced camera tracking. A silver-haired anime swordsman in a dark haori coat dashes across a shattered stone temple under a blood-red full moon, swinging a katana wreathed in crackling blue lightning and swirling water dragon effects. Sparks and glowing embers fly toward the camera in slow-motion impact frames, intense anime shading, dramatic motion blur.",
        visualEn: "High-budget ufotable anime action sakuga, dynamic fast-paced camera tracking. A silver-haired anime swordsman in a dark haori coat dashes across a shattered stone temple under a blood-red full moon, swinging a katana wreathed in crackling blue lightning and swirling water dragon effects. Sparks and glowing embers fly toward the camera in slow-motion impact frames, intense anime shading, dramatic motion blur.",
        soundscape: "Sharp metallic sword unsheathing and clashing clang, roaring thunder and crackling electric arcs, heavy stone debris crumbling, fierce battle cry.",
        music: "Epic dark orchestral battle music with fast taiko drums, intense choir, and distorted electric guitar riffs."
    ),
    PresetTemplate(
        id: "tpl_iceland_fpv",
        category: .videoAudio,
        nameZh: "[写实] 冰岛巨型瀑布 FPV 穿越机航拍",
        nameEn: "[Realism] Iceland Waterfall FPV Drone Dive",
        visualZh: "FPV drone shot diving down a majestic Icelandic waterfall surrounded by lush green moss and basalt columns under golden hour sunlight, mist rising into a rainbow.",
        visualEn: "FPV drone shot diving down a majestic Icelandic waterfall surrounded by lush green moss and basalt columns under golden hour sunlight, mist rising into a rainbow.",
        soundscape: "Roaring waterfall rushing water, wind whooshing past the camera, distant seabirds calling.",
        music: "Epic cinematic acoustic guitar and soaring cello."
    ),
    PresetTemplate(
        id: "tpl_cyber_poster",
        category: .image,
        nameZh: "[生图] 东方赛博霓虹商业海报（含中文排版）",
        nameEn: "[Image] Cyberpunk Neon Bund Poster (Chinese Title)",
        visualZh: "超清商业电影海报摄影，雨夜霓虹闪烁的未来上海外滩街道，一位身着机能风银色夹克的少女回眸凝视镜头，景深虚化光斑，顶部醒目发光现代中文字体排版写着“未来纪元 2026”，极致光影细节，8K画质。",
        visualEn: "Ultra-HD commercial sci-fi movie poster photography, rain-slicked cyberpunk Shanghai Bund street glowing with neon reflections at night, a young woman in a futuristic silver techwear jacket looking back at the camera, shallow depth of field bokeh flares, bold glowing modern title typography at the top reading \"FUTURE ERA 2026\" (未来纪元 2026), intricate lighting details, 8K.",
        soundscape: "",
        music: ""
    ),
    PresetTemplate(
        id: "tpl_film_cafe",
        category: .image,
        nameZh: "[生图] 胶片质感午后咖啡馆肖像",
        nameEn: "[Image] Hasselblad Film Afternoon Tokyo Cafe",
        visualZh: "Hasselblad medium format film photography, soft golden afternoon sunlight streaming through wooden blinds onto a cozy minimalist Tokyo cafe table, a ceramic pour-over coffee dripper with rising steam beside an open sketchbook, natural film grain, ultra-detailed textures.",
        visualEn: "Hasselblad medium format film photography, soft golden afternoon sunlight streaming through wooden blinds onto a cozy minimalist Tokyo cafe table, a ceramic pour-over coffee dripper with rising steam beside an open sketchbook, natural film grain, ultra-detailed textures.",
        soundscape: "",
        music: ""
    ),
    PresetTemplate(
        id: "tpl_llm_storyboard",
        category: .llmVLM,
        nameZh: "[推理] 为 AI 视频导演生成 3 组新海诚风分镜提示词",
        nameEn: "[Reasoning] Generate 3 Shinkai-Style AI Video Storyboard Prompts",
        visualZh: "请帮我构思 3 组极具画面感的新海诚风格动画短片分镜，每组包含：1) 英文 Visual & Camera 镜头提示词；2) Soundscape 环境音描述；3) Background Music 配乐描述。",
        visualEn: "Please design 3 vivid Makoto Shinkai-style anime short film storyboard shots. For each shot, provide: 1) Visual & Camera prompt; 2) Soundscape & SFX prompt; 3) Background Music prompt.",
        soundscape: "",
        music: ""
    ),
    PresetTemplate(
        id: "tpl_vlm_reverse",
        category: .llmVLM,
        nameZh: "[视觉] 深度解析图片构图并反推生图/生视频 Prompt",
        nameEn: "[Vision] Analyze Image Composition & Reverse-Engineer Prompt",
        visualZh: "请仔细观察这张图片的主体、光影色调、镜头景别与艺术风格，先做简要中文分析，然后反推出一段高质量的英文生图/生视频 Prompt。",
        visualEn: "Carefully analyze the subject, lighting, color palette, camera framing, and artistic style of this image. First give a concise visual breakdown, then write a high-quality English image/video generation prompt.",
        soundscape: "",
        music: ""
    ),
    // ── WorldForge 12 大师级镜头与场景母版（weiwei-custom fork 移植自旧魔改单文件） ──
    PresetTemplate(
        id: "wf_kamakura_sakura",
        category: .videoAudio,
        shortZh: "🌸 镰仓夕阳樱花少女",
        shortEn: "🌸 Kamakura Sakura Muse",
        nameZh: "🌸 镰仓夕阳 · 逆光樱花少女 (岩井俊二 85mm f/1.2L)",
        nameEn: "🌸 Kamakura Sunset · Backlit Sakura Girl (Iwai 85mm f/1.2L)",
        visualZh: "春日黄昏的镰仓木质车站，漫天樱花花瓣在夕阳逆光中缓慢飘落。一位清冷绝美的年轻东方女子身着轻盈丝质白裙，微风轻轻吹起她散落的栗色长发，她缓缓转头看向镜头，双眸清澈含光，白皙通透的脸颊带着淡淡的粉红红晕。Captured on ARRI Alexa 65 paired with vintage Canon FD 85mm f/1.2L lens wide open at f/1.2, Tiffen Black Pro-Mist 1/4 soft filter, warm golden hour backlighting creating a glowing amber rim light around her hair, translucent porcelain skin with delicate rosy blush and subsurface scattering, ultra-shallow depth of field, creamy dreamy bokeh, soft Tyndall light rays, Kodak Portra 400 film aesthetic, 8K masterpiece cinematography",
        visualEn: "A wooden train station in Kamakura at spring sunset, cherry blossom petals drifting slowly in golden hour backlight. A serene young East Asian woman in a flowing white silk dress turns gently toward the camera as a warm breeze lifts her chestnut hair, clear luminous eyes and translucent porcelain skin with a delicate rosy blush. Captured on ARRI Alexa 65 paired with vintage Canon FD 85mm f/1.2L lens wide open at f/1.2, Tiffen Black Pro-Mist 1/4 soft filter, glowing amber rim light, ultra-shallow depth of field, creamy dreamy bokeh, Kodak Portra 400 film aesthetic, 8K masterpiece cinematography",
        soundscape: "Gentle spring breeze rustling through cherry blossom branches, distant nostalgic wooden train station bell chiming softly, soft rustle of silk dress.",
        music: "Tender Iwai Shunji style solo acoustic piano melody with warm nostalgic strings.",
        cameraId: "iwai_85mm_f12",
        universalScene: true
    ),
    PresetTemplate(
        id: "wf_wkw_neon_rain",
        category: .videoAudio,
        shortZh: "🌧️ 花样年华霓虹雨窗",
        shortEn: "🌧️ WKW Neon Rain Window",
        nameZh: "🌧️ 花样年华 · 霓虹夜雨窗畔佳人 (王家卫 Cooke 40mm)",
        nameEn: "🌧️ In the Mood for Love · Neon Rain Window (WKW Cooke 40mm)",
        visualZh: "凌晨两点的香港霓虹雨夜，复古旅馆窗前雨滴沿着玻璃缓缓滑落，窗外翠绿与绯红色的霓虹灯牌在湿漉漉的街面晕染开迷离光斑。一位身姿曼妙的绝美东方女子斜倚在窗边，暖黄台灯与冷色霓虹在她细腻白皙微泛粉晕的脸庞与锁骨上交织出唯美光影，眼神迷离而深邃。Wong Kar-wai and Christopher Doyle aesthetic, shot on ARRI Alexa Mini LF with vintage Cooke Anamorphic/i 40mm T2.0 lens, creamy oval anamorphic bokeh, subtle horizontal blue-and-gold anamorphic lens flare streaks, rich emerald and crimson-amber color grading, 35mm Kodak Vision3 500T film grain, 8K masterpiece",
        visualEn: "2 AM rain-streaked vintage hotel window in Hong Kong, raindrops sliding down the glass as emerald and crimson neon signs blur into dreamy bokeh across the wet street outside. An elegant East Asian woman leans softly by the window, warm tungsten lamp light and cool neon reflections weaving across her porcelain face and collarbone, wistful cinematic gaze. Wong Kar-wai and Christopher Doyle aesthetic, shot on ARRI Alexa Mini LF with vintage Cooke Anamorphic/i 40mm T2.0 lens, creamy oval anamorphic bokeh, horizontal blue-and-gold lens flare streaks, 35mm Kodak Vision3 500T film grain, 8K masterpiece",
        soundscape: "Soft midnight rain tapping against window glass, distant muffled Hong Kong street traffic on wet asphalt, a quiet contemplative sigh.",
        music: "Melancholic slow waltz on solo violin and cello in the style of Shigeru Umebayashi (In the Mood for Love).",
        cameraId: "wong_kar_wai_anamorphic",
        universalScene: true
    ),
    PresetTemplate(
        id: "wf_golden_sea_muse",
        category: .videoAudio,
        shortZh: "🌊 橘子海日落少女",
        shortEn: "🌊 Golden Sunset Sea Muse",
        nameZh: "🌊 橘子海日落 · 逆光海风长发少女 (徕卡夜神 50mm f/0.95)",
        nameEn: "🌊 Amber Sea Sunset · Backlit Ocean Breeze (Leica Noctilux f/0.95)",
        visualZh: "日落时分的金色橘子海海滩，破碎的波浪闪烁着碎钻般的琥珀金光。一位绝美温柔的年轻少女赤足立于浅浪之中，海风拂起她灵动的长发与雪白轻纱裙摆，夕阳余晖穿透发丝勾勒出柔和金边，回眸一笑清澈动人，肌肤如羊脂白玉般通透。Shot on Sony Venice 2 8K paired with Leica Noctilux-M 50mm f/0.95 ASPH wide open, Tiffen Black Pro-Mist 1/4, golden hour rim lighting, dreamy swirly bokeh of glittering ocean waves, 8K cinema masterpiece",
        visualEn: "Golden sunset beach where breaking ocean waves sparkle like crushed amber diamonds. A graceful young woman stands barefoot in the shallow surf as the sea breeze lifts her flowing hair and white chiffon dress, sunset rays outlining her hair in warm gold as she looks back with a radiant smile. Shot on Sony Venice 2 8K paired with Leica Noctilux-M 50mm f/0.95 ASPH wide open, Tiffen Black Pro-Mist 1/4, golden hour rim lighting, dreamy swirly bokeh of glittering ocean waves, 8K cinema masterpiece",
        soundscape: "Gentle ocean waves lapping against the sandy shore, warm coastal breeze, distant seagulls crying softly in the sunset.",
        music: "Warm dreamy indie acoustic guitar and ambient synth pad.",
        cameraId: "leica_noctilux_f095",
        universalScene: true
    ),
    PresetTemplate(
        id: "wf_jiangnan_misty_boat",
        category: .videoAudio,
        shortZh: "🛶 烟雨江南乌篷船",
        shortEn: "🛶 Misty Jiangnan Boat",
        nameZh: "🛶 烟雨江南 · 乌篷船头撑伞回眸 (迪金斯 IMAX 65mm)",
        nameEn: "🛶 Misty Jiangnan · Oil-Paper Umbrella on Wooden Boat (Deakins IMAX)",
        visualZh: "清晨烟雨蒙蒙的江南水乡古镇，青石拱桥下碧水如镜，薄雾与炊烟在河面缓缓流淌。一叶乌篷船轻轻划过水面，船头立着一位身着素雅宋制汉服的清丽江南女子，手执油纸伞微微抬眸，晨曦金光穿透薄雾洒落。Roger Deakins IMAX 65mm cinematography, Panavision Primo 70 50mm T1.9 lens, volumetric morning mist and soft god rays, poetic Chinese ink-and-gold color palette, 8K masterpiece",
        visualEn: "Misty dawn in an ancient Jiangnan water town, emerald canal water beneath a stone arch bridge with morning fog drifting softly. A traditional wooden boat glides across the water as a graceful woman in Song Dynasty Hanfu stands at the bow holding an oil-paper umbrella, golden dawn rays piercing the mist. Roger Deakins IMAX 65mm cinematography, Panavision Primo 70 50mm T1.9 lens, volumetric morning mist and soft god rays, poetic Chinese ink-and-gold color palette, 8K masterpiece",
        soundscape: "Wooden oar gently dipping into calm canal water, light spring drizzle pattering on an oil-paper umbrella, distant morning birdsong.",
        music: "Poetic Chinese guzheng and bamboo flute xiao melody echoing softly over water.",
        cameraId: "deakins_imax_65mm",
        universalScene: true
    ),
    PresetTemplate(
        id: "wf_ghibli_laputa",
        category: .videoAudio,
        shortZh: "🏰 宫崎骏天空之城",
        shortEn: "🏰 Ghibli Floating Castle",
        nameZh: "🏰 宫崎骏 · 天空之城浮岛花海 (单点透视穿梭)",
        nameEn: "🏰 Studio Ghibli · Laputa Floating Sky Island (Perspective Flythrough)",
        visualZh: "宫崎骏《天空之城》风格的漂浮天空之岛，晴朗夏日，湛蓝天空堆满巨大洁白积云，一条长满青草与小野花的古老石板小路从画面正下方中央笔直延伸向远方，两侧是爬满藤蔓的古老石拱门一座接一座排成长廊，尽头是被巨大古树覆盖的圆形古城堡，岛边小瀑布流向云海，单点透视，层次丰富，吉卜力手绘动画美术风格，原生2K",
        visualEn: "Studio Ghibli Castle in the Sky style floating island on a bright summer day, towering white cumulus clouds in a deep cobalt sky. An ancient grassy stone path with wildflowers extends straight from bottom center in one-point perspective through a corridor of ivy-covered stone arches toward a circular ancient ruin crowned by a giant tree, small waterfalls cascading into the cloud sea, rich hand-painted anime background, 8K masterpiece",
        soundscape: "High-altitude summer wind sweeping through tall grass and wildflowers, gentle waterfall cascading into clouds, distant singing birds.",
        music: "Joe Hisaishi style sweeping symphonic orchestra with nostalgic trumpet and piano main theme.",
        cameraId: "shinkai_twilight_panavision",
        universalScene: true
    ),
    PresetTemplate(
        id: "wf_torii_maple",
        category: .videoAudio,
        shortZh: "⛩️ 京都千本鸟居红枫",
        shortEn: "⛩️ Kyoto Torii & Maples",
        nameZh: "⛩️ 千本鸟居 · 京都深秋红枫神道 (迪金斯丁达尔神光)",
        nameEn: "⛩️ Fushimi Inari · Vermilion Torii & Autumn Maples (Deakins God Rays)",
        visualZh: "深秋京都伏见稻荷，成千上万座朱红色鸟居层层叠叠组成的幽深隧道，沿着长满青苔的石阶一路向山林深处延伸，鸟居外是燃烧般火红与金黄的枫叶，金色夕阳光束从缝隙间穿透，薄雾弥漫，单点透视，电影级实拍质感，原生2K",
        visualEn: "Late autumn at Fushimi Inari Kyoto, an endless tunnel of thousands of vermilion torii gates ascending mossy stone steps into the mountain forest, surrounded by blazing crimson and golden maple leaves, golden sunset Tyndall light beams piercing through the gaps in soft mist, one-point perspective, 8K IMAX cinematography",
        soundscape: "Soft mountain breeze rustling autumn maple leaves, distant shishi-odoshi bamboo water fountain clacking, serene forest ambiance.",
        music: "Zen Japanese koto and shakuhachi flute with warm ambient strings.",
        cameraId: "deakins_imax_65mm",
        universalScene: true
    ),
    PresetTemplate(
        id: "wf_lost_temple",
        category: .videoAudio,
        shortZh: "🏛️ 雨林失落神殿",
        shortEn: "🏛️ Jungle Lost Temple",
        nameZh: "🏛️ 雨林失落神殿 · 丁达尔神光峡谷 (IMAX 史诗场景)",
        nameEn: "🏛️ Rainforest Lost Temple · Volumetric Canyon (IMAX Epic)",
        visualZh: "被热带雨林吞没的远古失落神殿峡谷，古老石板步道穿过两侧巨型石刻神像与爬满藤蔓的石柱长廊，延伸向远处巨大的金字塔神殿，瀑布从悬崖倾泻，丁达尔光柱，薄雾缭绕，单点透视，电影级实拍质感，原生2K",
        visualEn: "An ancient lost temple canyon swallowed by tropical rainforest, a weathered stone causeway passing between colossal carved guardian statues and vine-draped pillars toward a giant stepped pyramid temple in the distance, waterfalls plunging down cliffs, dramatic volumetric god rays piercing jungle mist, one-point perspective, 8K IMAX cinematography",
        soundscape: "Distant thundering jungle waterfalls, exotic tropical birds echoing through the canyon, water droplets dripping from moss-covered stone.",
        music: "Majestic adventure orchestral score with deep brass, tribal percussion, and ethereal choir.",
        cameraId: "deakins_imax_65mm",
        universalScene: true
    ),
    PresetTemplate(
        id: "wf_ice_palace",
        category: .videoAudio,
        shortZh: "❄️ 极光冰晶宫殿",
        shortEn: "❄️ Aurora Ice Palace",
        nameZh: "❄️ 极光冰晶宫殿 · 凛冬银河圣殿",
        nameEn: "❄️ Aurora Crystal Ice Palace · Winter Galaxy Sanctuary",
        visualZh: "极光之夜的冰雪水晶宫殿长廊，晶莹冰面长廊两侧是高耸的冰晶柱与冰雕拱门层层向远方延伸，冰柱透出幽蓝青绿光芒，天空绚烂极光，远处巨大冰晶城堡，单点透视，原生2K",
        visualEn: "A grand translucent crystal ice palace corridor beneath a starry arctic night sky ablaze with emerald and violet aurora borealis, mirror-like ice floor flanked by towering carved ice pillars and arches glowing with cyan internal light, leading toward a colossal ice citadel, one-point perspective, 8K masterpiece",
        soundscape: "Crystalline wind chiming softly through ice arches, subtle glacial resonance, crisp arctic night air.",
        music: "Ethereal celesta, glass harp, and soaring Nordic choir.",
        cameraId: "shinkai_twilight_panavision",
        universalScene: true
    ),
    PresetTemplate(
        id: "wf_lantern_town",
        category: .videoAudio,
        shortZh: "🏮 千灯古镇盛唐水乡",
        shortEn: "🏮 Thousand-Lantern Town",
        nameZh: "🏮 千灯古镇长街 · 盛唐不夜水乡",
        nameEn: "🏮 Thousand-Lantern Ancient Water Town · Tang Dynasty Night",
        visualZh: "夜晚的中国古风水乡长街，青石板路沿河道延伸向远方，两侧层层叠叠的木结构古楼挂满成百上千盏暖红灯笼，石拱桥横跨河面，远处灯火辉煌的高塔，单点透视，原生2K",
        visualEn: "Nighttime in a grand ancient Chinese water town, wet bluestone street running alongside a glowing canal, multi-tiered wooden pavilions on both sides hung with thousands of warm red lanterns reflecting in the water, stone arch bridges and a golden illuminated pagoda in the distance, one-point perspective, 8K masterpiece",
        soundscape: "Gentle canal water lapping against stone embankments, soft evening breeze swaying silk lanterns, distant festive pipa lute notes.",
        music: "Grand Tang Dynasty orchestral court music with pipa, guzheng, and warm cinematic strings.",
        cameraId: "wong_kar_wai_anamorphic",
        universalScene: true
    ),
    PresetTemplate(
        id: "wf_cyber_alley",
        category: .videoAudio,
        shortZh: "🌃 赛博朋克霓虹雨巷",
        shortEn: "🌃 Cyberpunk Rain Alley",
        nameZh: "🌃 赛博朋克雨夜 · 银翼杀手霓虹窄巷",
        nameEn: "🌃 Cyberpunk Rainy Night · Blade Runner Neon Alley",
        visualZh: "雨夜赛博朋克未来都市窄巷，湿漉漉街道倒映漫天霓虹，两侧高楼贴满巨大全息广告牌，空中交错电缆与天桥，巷子尽头耸入云霄的巨型摩天楼，单点透视，原生2K",
        visualEn: "Rain-soaked cyberpunk metropolis narrow alley at night, wet asphalt mirroring vibrant cyan and magenta holographic billboards on towering megastructures, crisscrossing overhead cables and skybridges, a colossal megatower rising into storm clouds at the end of the corridor, Blade Runner 2049 cinematography, 8K",
        soundscape: "Heavy rain pouring onto neon-lit asphalt, low hum of futuristic neon transformers and distant spinner aircraft overhead.",
        music: "Vangelis & Hans Zimmer style deep analog synthesizer bass and atmospheric cyberpunk pad.",
        cameraId: "wong_kar_wai_anamorphic",
        universalScene: true
    ),
    PresetTemplate(
        id: "wf_underwater_atlantis",
        category: .videoAudio,
        shortZh: "🌊 深海亚特兰蒂斯",
        shortEn: "🌊 Underwater Atlantis",
        nameZh: "🌊 深海亚特兰蒂斯 · 水下圣殿丁达尔光束",
        nameEn: "🌊 Underwater Atlantis · Submerged Marble Sanctuary",
        visualZh: "幽蓝深海下的亚特兰蒂斯古老大理石神殿长廊，洁白石板大道从画面正下方笔直通向远方发光的巨型圆顶水下圣殿，两侧是缠绕着发光珊瑚与海藻的科林斯石柱拱门，阳光透过海水形成壮丽的丁达尔光束，单点透视，原生2K",
        visualEn: "Submerged ancient Atlantis marble colonnade on the deep sapphire ocean floor, a white stone avenue leading straight toward a glowing domed underwater sanctuary, flanked by Corinthian pillars draped in bioluminescent coral and kelp, dramatic underwater sunbeams piercing the deep blue water, one-point perspective, 8K",
        soundscape: "Deep resonant underwater currents, gentle rising bubble streams, distant whale song echoing through the ocean depths.",
        music: "Mystical ambient synthesizer and harp with deep oceanic sub-bass.",
        cameraId: "deakins_imax_65mm",
        universalScene: true
    ),
    PresetTemplate(
        id: "wf_dunhuang_grotto",
        category: .videoAudio,
        shortZh: "✨ 敦煌鎏金飞天石窟",
        shortEn: "✨ Dunhuang Gilded Grotto",
        nameZh: "✨ 敦煌鎏金石窟 · 盛唐飞天佛殿",
        nameEn: "✨ Dunhuang Gilded Grotto · Tang Dynasty Celestial Hall",
        visualZh: "恢弘壮丽的盛唐敦煌莫高窟皇家佛殿长廊，地面铺设发光青金石地砖从正下方笔直延伸向远方，两侧是绘满绚丽飞天壁画与悬浮金色藻井的朱红雕花木柱拱廊，尽头是一尊庄严宏伟的鎏金巨佛坐像，金色体积光柱穿透殿堂，单点透视，原生2K",
        visualEn: "Magnificent Tang Dynasty Dunhuang Mogao royal cave temple corridor, glowing lapis lazuli floor tiles extending straight in one-point perspective between vermilion carved pillars painted with vibrant flying apsaras murals and golden caisson ceilings, leading to a colossal gilded Buddha statue bathed in golden volumetric light shafts, 8K masterpiece",
        soundscape: "Deep resonant bronze temple bell chime echoing in a vast stone hall, subtle fluttering of silk banners.",
        music: "Sacred Dunhuang ancient pipa,konghou harp, and ethereal Buddhist choir.",
        cameraId: "deakins_imax_65mm",
        universalScene: true
    ),
    // ── 导演扩写模板（weiwei-custom fork 移植自旧魔改单文件） ──
    PresetTemplate(
        id: "tpl_llm_cinema_director",
        category: .llmVLM,
        shortZh: "🎥 岩井俊二/王家卫电影扩写",
        shortEn: "🎥 Iwai / WKW Cinema Director",
        nameZh: "[导演] 用 ARRI 电影摄影机光学语言扩写生图/音视频提示词",
        nameEn: "[Director] Expand Scene into ARRI / Cooke Anamorphic Cinema Prompts",
        visualZh: "你现在是顶级电影摄影指导（熟悉岩井俊二 ARRI Alexa 65 + Canon FD 85mm f/1.2L 逆光柔焦、王家卫 Cooke Anamorphic 40mm 变形宽银幕、罗杰·迪金斯 IMAX 65mm 丁达尔体积光、徕卡 Noctilux 50mm f/0.95）。请以「雨后黄昏的江南古镇茶馆或东京街角」为主题，为我编写 2 组可直接用于生图与音视频同生的大师级中英双语 Prompt（包含机身镜头参数、光影构图、环境音效 Soundscape 与配乐 Music）。",
        visualEn: "Act as a master cinematographer well-versed in ARRI Alexa 65 + Canon FD 85mm f/1.2L (Iwai Shunji), Cooke Anamorphic 40mm (Wong Kar-wai), IMAX 65mm (Roger Deakins), and Leica Noctilux 50mm f/0.95. Create 2 master-level image & audio-video prompts with full camera/lens/filter suffixes, Soundscape foley, and Background Music.",
        soundscape: "",
        music: ""
    )

]

// MARK: - 网络协议结构

struct LoadedModelSummary: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var mode: String?
    var vram_gb: Double?
    var context_length: Int?

    var localizedName: String {
        if let spec = OPEN_MODEL_CATALOG.first(where: { $0.id == id }) {
            return spec.name
        }
        return localizeServerText(name)
    }
}

struct ColabStatusResponse: Codable {
    var ok: Bool?
    var cuda_available: Bool?
    var gpu_name: String?
    var vram_free_gb: Double?
    var vram_total_gb: Double?
    var vram_used_gb: Double?
    var model_loaded: Bool?
    var any_model_loaded: Bool?
    var selected_model_id: String?
    var loaded_model_id: String?
    var loaded_model_ids: [String]?
    var loaded_models_detail: [LoadedModelSummary]?
    var current_model: String?
    var message: String?
    var context_length: Int?
    var loaded_context_length: Int?

    var files: [ModelFileItem]?
    var downloaded_count: Int?
    var total_count: Int?
    var all_downloaded: Bool?
    var total_size_gb: Double?
    var drive_persisted: Bool?
    var bf16_shards_count: Int?
    var is_downloading: Bool?
    var is_loading_vram: Bool?
    var task_progress: Double?
    var task_message: String?

    var uptime_seconds: Int?
    var cu_burn_rate_per_hour: Double?
    var session_cu_used: Double?
    var idle_timeout_minutes: Int?
    var idle_remaining_seconds: Int?
    var api_key_enabled: Bool?
    var api_key_configured: Bool?
    var api_request_count: Int?
    var console_lines: [String]?

    var ram_total_gb: Double?
    var ram_used_gb: Double?
    var ram_free_gb: Double?
    var disk_total_gb: Double?
    var disk_used_gb: Double?
    var disk_free_gb: Double?
    var shm_total_gb: Double?
    var shm_used_gb: Double?
    var shm_free_gb: Double?
    var drive_total_gb: Double?
    var drive_used_gb: Double?
    var drive_free_gb: Double?
    var comfyui: ComfyRemoteStatus?
    var custom_models: [CustomHFModelDTO]?
    var registered_model: CustomHFModelDTO?
    var action_ok: Bool?
    var action_message: String?
}

struct ComfyOutputMediaItem: Codable, Identifiable, Hashable {
    var id: String { rel_path }
    var rel_path: String
    var filename: String
    var media_type: String?
    var size_mb: Double?
    var mtime: Int?
}

struct ComfyPresetPackItem: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var badge: String
    var scenario: String
    var approx_size_gb: Double
    var workflows: [String]
    var installed_models: Int
    var total_models: Int
    var workflows_installed: Bool
    var ready: Bool

    var localizedTitle: String {
        guard LanguageManager.shared.isEN else { return title }
        switch id {
        case "wan22_i2v_flf2v":
            return "Wan2.2 14B · Image-to-Video + First/Last Frame Dual Workflows"
        case "minimax_h3_i2v_flf2v":
            return "MiniMax-H3 Turbo · Image-to-Video+Audio + First/Last Frame"
        case "ltx23_flf2v":
            return "LTX-2.3 (22B) · Cinematic Camera Motion First/Last Frame + Audio"
        case "hunyuan15_i2v_1080p":
            return "HunyuanVideo 1.5 · Single-Image Direct 1080P Super-Res Workflow"
        default:
            return localizeServerText(title)
        }
    }

    var localizedBadge: String {
        guard LanguageManager.shared.isEN else { return badge }
        switch id {
        case "wan22_i2v_flf2v":
            return "Beginner Pick · 4-Step Fast"
        case "minimax_h3_i2v_flf2v":
            return "Stereo Audio · 8-Step Turbo"
        case "ltx23_flf2v":
            return "Cinematic Camera · Only 2 Weights"
        case "hunyuan15_i2v_1080p":
            return "720P + 1080P Dual Output"
        default:
            return localizeServerText(badge)
        }
    }

    var localizedScenario: String {
        guard LanguageManager.shared.isEN else { return scenario }
        switch id {
        case "wan22_i2v_flf2v":
            return "Includes 'Single Image to Video' & 'First/Last Frame Smooth Transition' templates (~25s on G4, 100% built-in nodes, zero missing-node errors)"
        case "minimax_h3_i2v_flf2v":
            return "Includes single-image and first/last-frame templates generating HD video with synchronized stereo SFX, dialogue & music in one pass"
        case "ltx23_flf2v":
            return "Optimized for dramatic camera moves between start & end keyframes (e.g. aerial crane dive to low-angle close-up + synthesized soundtrack)"
        case "hunyuan15_i2v_1080p":
            return "Latent super-resolution pipeline enabled by default — upload 1 image to render both 720P base video and 1920×1080 Full HD output"
        default:
            return localizeServerText(scenario)
        }
    }

    static func localizedWorkflowLabel(_ rawName: String) -> String {
        let stripped = rawName.replacingOccurrences(of: ".json", with: "")
        guard LanguageManager.shared.isEN else { return stripped }
        let map: [String: String] = [
            "01_Wan2.2_极速单图生视频(4步傻瓜版)": "01_Wan2.2_Fast_Single_I2V_4Step",
            "02_Wan2.2_首尾帧丝滑过渡(双图4步极速)": "02_Wan2.2_FirstLastFrame_4Step",
            "03_MiniMax-H3_极速图生有声视频(单图带立体声)": "03_MiniMax-H3_Fast_I2VA_Stereo",
            "04_MiniMax-H3_首尾帧有声过渡(双图带立体声)": "04_MiniMax-H3_FirstLastFrame_Stereo",
            "05_LTX-2.3_首尾帧电影运镜(双图极速带音效)": "05_LTX-2.3_Cinematic_FLF2V_Audio",
            "06_Hunyuan1.5_单图直出1080P超清视频": "06_Hunyuan1.5_Direct_1080P_I2V"
        ]
        return map[stripped] ?? stripped
    }
}

let DEFAULT_COMFY_PRESET_PACKS: [ComfyPresetPackItem] = [
    ComfyPresetPackItem(
        id: "wan22_i2v_flf2v",
        title: "万相 Wan2.2 14B · 图生视频 + 首尾帧双工作流",
        badge: "新手首选 · 4步极速",
        scenario: "含「单图动起来」与「首尾双图丝滑过渡」2 套中文画布，G4 约 25 秒出片，纯官方内置节点零红框报错",
        approx_size_gb: 35.4,
        workflows: [
            "01_Wan2.2_极速单图生视频(4步傻瓜版).json",
            "02_Wan2.2_首尾帧丝滑过渡(双图4步极速).json"
        ],
        installed_models: 0,
        total_models: 6,
        workflows_installed: false,
        ready: false
    ),
    ComfyPresetPackItem(
        id: "minimax_h3_i2v_flf2v",
        title: "MiniMax-H3 Turbo · 图生有声视频 + 首尾帧双工作流",
        badge: "自带立体声音效 · 8步加速",
        scenario: "含「单图生有声视频」与「首尾双图有声过渡」2 套极简画布，一次生成高清动态画面 + 同步环境音效/配乐/对白",
        approx_size_gb: 39.1,
        workflows: [
            "03_MiniMax-H3_极速图生有声视频(单图带立体声).json",
            "04_MiniMax-H3_首尾帧有声过渡(双图带立体声).json"
        ],
        installed_models: 0,
        total_models: 5,
        workflows_installed: false,
        ready: false
    ),
    ComfyPresetPackItem(
        id: "ltx23_flf2v",
        title: "LTX-2.3 (22B) · 首尾帧电影级运镜有声工作流",
        badge: "电影推拉摇移 · 仅 2 个权重",
        scenario: "专为首尾关键帧大幅度镜头运动优化（如高空俯拍平滑推镜至低角度特写 + 自动合成配乐音轨）",
        approx_size_gb: 36.3,
        workflows: [
            "05_LTX-2.3_首尾帧电影运镜(双图极速带音效).json"
        ],
        installed_models: 0,
        total_models: 2,
        workflows_installed: false,
        ready: false
    ),
    ComfyPresetPackItem(
        id: "hunyuan15_i2v_1080p",
        title: "混元 HunyuanVideo 1.5 · 单图直出 1080P 超分工作流",
        badge: "720P + 1080P 双路超清",
        scenario: "已默认激活潜空间超分管线，传 1 张图一键自动渲染 720P 原片与 1920×1080 超高清成片",
        approx_size_gb: 43.5,
        workflows: [
            "06_Hunyuan1.5_单图直出1080P超清视频.json"
        ],
        installed_models: 0,
        total_models: 7,
        workflows_installed: false,
        ready: false
    )
]

struct ComfyRemoteStatus: Codable {
    var is_running: Bool?
    var is_starting: Bool?
    var is_syncing_drive: Bool?
    var is_downloading_weight: Bool?
    var installing_pack_id: String?
    var progress: Double?
    var status_message: String?
    var public_url: String?
    var local_port: Int?
    var queue_running: Int?
    var queue_pending: Int?
    var persistence_mode: String?
    var persistence_label: String?
    var drive_persisted: Bool?
    var persist_root: String?
    var custom_nodes_count: Int?
    var models_count: Int?
    var workflows_count: Int?
    var last_sync_ts: Int?
    var recent_outputs: [ComfyOutputMediaItem]?
    var preset_packs: [ComfyPresetPackItem]?
}

struct CompletedMediaItem: Codable, Hashable {
    var index: Int?
    var seed: Int?
    var filename: String
    var video_url: String
    var media_type: String?
    var elapsed: Double?
}

struct LiveTelemetrySnapshot: Codable {
    var cuda_available: Bool?
    var gpu_name: String?
    var vram_free_gb: Double?
    var vram_total_gb: Double?
    var vram_used_gb: Double?
    var cu_burn_rate_per_hour: Double?
    var ram_total_gb: Double?
    var ram_used_gb: Double?
    var ram_free_gb: Double?
    var disk_total_gb: Double?
    var disk_used_gb: Double?
    var disk_free_gb: Double?
    var shm_total_gb: Double?
    var shm_used_gb: Double?
    var shm_free_gb: Double?
    var drive_total_gb: Double?
    var drive_used_gb: Double?
    var drive_free_gb: Double?
}

struct ColabJobResponse: Codable {
    var job_id: String
    var model_id: String?
    var status: String
    var progress: Double
    var message: String
    var seed: Int?
    var elapsed: Double?
    var filename: String?
    var video_url: String?
    var media_type: String?
    var text_output: String?
    var thinking_output: String?
    var batch_count: Int?
    var completed_count: Int?
    var completed_videos: [CompletedMediaItem]?
    var console_lines: [String]?
    var telemetry: LiveTelemetrySnapshot?
}

struct BridgeAuthStatusResponse: Codable {
    var ok: Bool?
    var logged_in: Bool?
    var email: String?
    var paid_balance: Double?
    var burn_rate_hourly: Double?
    var active_assignments: Int?
    var message: String?
    var error: String?
}

struct LocalMediaItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let filename: String
    let isImage: Bool
    let createdAt: Date
    let elapsedSeconds: Double?
}

func formatDuration(_ sec: Double, compact: Bool = false) -> String {
    let s = max(0.0, sec)
    if s < 60.0 {
        if compact { return String(format: "%.1fs", s) }
        return LanguageManager.shared.isEN
            ? String(format: "%.1f s", s)
            : String(format: "%.1f 秒", s)
    }
    let mins = Int(s) / 60
    let rem = s - Double(mins * 60)
    if compact { return String(format: "%dm%.0fs", mins, rem) }
    return LanguageManager.shared.isEN
        ? String(format: "%dm %.1fs", mins, rem)
        : String(format: "%d分%.1f秒", mins, rem)
}

struct HFTrendingModelItem: Identifiable, Codable, Hashable {
    var id: String { repo_id }
    let repo_id: String
    let name: String
    let pipeline_tag: String
    let modality: String
    let is_gguf: Bool
    let is_gated: Bool
    let suggested_pattern: String
    let likes: Int
    let downloads: Int
    var param_count: Int? = nil
    var param_label: String? = nil
    var est_vram_gb: Double? = nil
    var deploy_status: String? = nil
    var deploy_label_zh: String? = nil
    var deploy_label_en: String? = nil

    var localizedDeployLabel: String {
        let rawZh = (deploy_label_zh?.isEmpty == false) ? deploy_label_zh! : "显存待探测"
        let rawEn = (deploy_label_en?.isEmpty == false) ? deploy_label_en! : "VRAM TBD"
        return stripEmojiCharacters(L(rawZh, rawEn))
    }

    var deployBadgeColor: Color {
        switch deploy_status ?? "unknown" {
        case "great", "good":
            return .green
        case "a100":
            return Color(red: 0.85, green: 0.62, blue: 0.05)
        case "heavy":
            return .orange
        case "too_large":
            return .red
        default:
            return .secondary
        }
    }
}


struct HFTrendingAPIResponse: Codable {
    var ok: Bool?
    var category: String?
    var models: [HFTrendingModelItem]?
}

struct HFModelWeightFileItem: Identifiable, Codable, Hashable {
    var id: String { filename }
    let filename: String
    let size_gb: Double
    let fit_status: String
    let fit_zh: String
    let fit_en: String

    var localizedFit: String { stripEmojiCharacters(L(fit_zh, fit_en)) }

    var fitColor: Color {
        switch fit_status {
        case "great", "good": return .green
        case "a100": return Color(red: 0.85, green: 0.62, blue: 0.05)
        case "heavy": return .orange
        case "too_large": return .red
        default: return .secondary
        }
    }
}

struct HFModelDetailInfo: Identifiable, Codable, Hashable {
    var id: String { repo_id }
    var ok: Bool?
    var repo_id: String
    var name: String
    var author: String
    var pipeline_tag: String
    var modality: String
    var is_gguf: Bool
    var is_gated: Bool
    var license: String
    var base_model: String
    var architecture: String
    var context_length: Int
    var languages: [String]
    var likes: Int
    var downloads: Int
    var last_modified: String
    var used_storage_gb: Double
    var param_count: Int
    var param_label: String
    var est_vram_gb: Double
    var deploy_status: String
    var deploy_label_zh: String
    var deploy_label_en: String
    var weight_files: [HFModelWeightFileItem]
    var readme_excerpt: String

    var localizedDeployLabel: String {
        stripEmojiCharacters(L(deploy_label_zh.isEmpty ? "显存待探测" : deploy_label_zh, deploy_label_en.isEmpty ? "VRAM TBD" : deploy_label_en))
    }

    var deployBadgeColor: Color {
        switch deploy_status {
        case "great", "good": return .green
        case "a100": return Color(red: 0.85, green: 0.62, blue: 0.05)
        case "heavy": return .orange
        case "too_large": return .red
        default: return .secondary
        }
    }
}

struct ChatTurnItem: Identifiable, Hashable {
    let id = UUID()
    var role: String      // "user" or "assistant"
    var content: String
    var thinking: String = ""
    var hasImage: Bool = false
}


// MARK: - 界面色彩主题（左中右三栏高辨识度分界）

struct StudioPalette {
    let colorScheme: ColorScheme

    // 左侧控制栏：冷灰蓝底色
    var sidebarBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.110, green: 0.120, blue: 0.145)
            : Color(red: 0.912, green: 0.928, blue: 0.955)
    }

    // 左侧卡片底色
    var sidebarCardFill: Color {
        colorScheme == .dark
            ? Color(red: 0.155, green: 0.168, blue: 0.200)
            : Color(red: 0.985, green: 0.990, blue: 1.000)
    }

    // 中间主工作区画布底色
    var workspaceCanvas: Color {
        colorScheme == .dark
            ? Color(red: 0.072, green: 0.078, blue: 0.094)
            : Color(red: 0.974, green: 0.978, blue: 0.986)
    }

    // 中间工作区卡片底色
    var workspaceCardFill: Color {
        colorScheme == .dark
            ? Color(red: 0.125, green: 0.135, blue: 0.162)
            : Color.white
    }

    // 右侧运行日志面板顶栏底色
    var logHeaderBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.102, green: 0.112, blue: 0.136)
            : Color(red: 0.924, green: 0.934, blue: 0.954)
    }

    // 右侧运行日志面板背景色
    var logPanelBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.088, green: 0.096, blue: 0.118)
            : Color(red: 0.938, green: 0.945, blue: 0.960)
    }

    // 右侧深色终端视口底色
    var logTerminalFill: Color {
        Color(red: 0.072, green: 0.082, blue: 0.104)
    }

    // 左中右面板分界线颜色
    var splitDivider: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color(red: 0.76, green: 0.80, blue: 0.86)
    }

    // 卡片边框色
    var cardBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.09)
            : Color(red: 0.82, green: 0.85, blue: 0.90)
    }

    // 输入框底色
    var inputFill: Color {
        colorScheme == .dark
            ? Color(red: 0.090, green: 0.098, blue: 0.118)
            : Color(red: 0.985, green: 0.988, blue: 0.994)
    }
}

// MARK: - 跨环境动态路径与自包含运行支撑

enum LocalRuntimePaths {
    /// 若应用位于源码仓库目录 (<repo>/EasyColab.app)，优先读取仓库内文件以便开发热更新；
    /// 若被独立安装至 /Applications，自动回退使用 EasyColab.app/Contents/Resources 内置资源。
    static var repoRootIfPresent: URL? {
        let fm = FileManager.default
        let bundleParent = Bundle.main.bundleURL.deletingLastPathComponent()
        if fm.fileExists(atPath: bundleParent.appendingPathComponent("app.py").path),
           fm.fileExists(atPath: bundleParent.appendingPathComponent("colab_bridge.py").path) {
            return bundleParent
        }
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)
        if fm.fileExists(atPath: cwd.appendingPathComponent("app.py").path),
           fm.fileExists(atPath: cwd.appendingPathComponent("colab_bridge.py").path) {
            return cwd
        }
        return nil
    }

    static func resolveBundledOrRepoFile(_ filename: String) -> String {
        let fm = FileManager.default
        if let repo = repoRootIfPresent {
            let p = repo.appendingPathComponent(filename).path
            if fm.fileExists(atPath: p) { return p }
        }
        if let res = Bundle.main.resourceURL {
            let p = res.appendingPathComponent(filename).path
            if fm.fileExists(atPath: p) { return p }
        }
        return filename
    }

    static var appSupportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("EasyColab", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var managedVenvDir: URL {
        appSupportDir.appendingPathComponent("venv", isDirectory: true)
    }

    static func findReadyBridgePython() -> String? {
        let fm = FileManager.default
        var candidates: [String] = []
        if let repo = repoRootIfPresent {
            candidates.append(repo.appendingPathComponent(".venv/bin/python").path)
            candidates.append(repo.appendingPathComponent("venv/bin/python").path)
        }
        candidates.append(managedVenvDir.appendingPathComponent("bin/python").path)
        for py in candidates where fm.isExecutableFile(atPath: py) {
            let check = Process()
            check.executableURL = URL(fileURLWithPath: py)
            check.arguments = ["-c", "import colab_cli, google.auth, websocket"]
            check.standardOutput = Pipe()
            check.standardError = Pipe()
            if (try? check.run()) != nil {
                check.waitUntilExit()
                if check.terminationStatus == 0 {
                    return py
                }
            }
        }
        return nil
    }

    static func findSystemPython3() -> String? {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/usr/bin/python3"
        ]
        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }
}

