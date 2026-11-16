import SwiftUI

struct SettingsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingDeepSeekApiKey: Bool = false
    @State private var isShowingGeminiApiKey: Bool = false
    @State private var deepseekConnectionState: AIConnectionState = .idle
    @State private var geminiConnectionState: AIConnectionState = .idle

    var body: some View {
        @Bindable var prefs = appState.prefs

        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PREFERENCES & CONFIGURATION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(KazeTheme.vermilion)
                    Text(prefs.language == .ja ? "環境設定" : "偏好设置")
                        .font(.system(size: 20, weight: .bold))
                }
                Spacer()
                Button(prefs.language == .ja ? "完了" : "完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(KazeTheme.vermilion)
            }

            Divider()

            Form {
                // Section 1: Units
                Section {
                    Picker(prefs.language == .ja ? "ペース単位" : "配速单位", selection: $prefs.paceUnit) {
                        ForEach(PaceUnit.allCases) { u in
                            Text(u.label(lang: prefs.language)).tag(u)
                        }
                    }

                    Picker(prefs.language == .ja ? "距離単位" : "距离单位", selection: $prefs.distanceUnit) {
                        ForEach(DistanceUnit.allCases) { u in
                            Text(u.label(lang: prefs.language)).tag(u)
                        }
                    }

                    Picker(prefs.language == .ja ? "温度単位" : "温度单位", selection: $prefs.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases) { u in
                            Text(u.label(lang: prefs.language)).tag(u)
                        }
                    }

                    Picker(prefs.language == .ja ? "高度単位" : "海拔高度单位", selection: $prefs.elevationUnit) {
                        ForEach(ElevationUnit.allCases) { u in
                            Text(u.label(lang: prefs.language)).tag(u)
                        }
                    }
                } header: {
                    Text(prefs.language == .ja ? "測定単位" : "计量单位")
                        .font(.system(size: 11, weight: .bold))
                }

                // Section 2: Appearance & Language
                Section {
                    Picker(prefs.language == .ja ? "言語" : "界面语言", selection: $prefs.language) {
                        ForEach(AppLanguage.allCases) { l in
                            Text(l.label).tag(l)
                        }
                    }

                    Picker(prefs.language == .ja ? "外観モード" : "外观明暗", selection: $prefs.appearance) {
                        ForEach(AppAppearance.allCases) { a in
                            Text(a.label(lang: prefs.language)).tag(a)
                        }
                    }
                } header: {
                    Text(prefs.language == .ja ? "表示とデザイン" : "显示与语言")
                        .font(.system(size: 11, weight: .bold))
                }

                // Section 3: Map Provider & Calibration
                Section {
                    Picker(prefs.language == .ja ? "地図サービス源" : "地图底图服务", selection: $prefs.mapProvider) {
                        ForEach(MapProvider.allCases) { p in
                            Text(p.label(lang: prefs.language)).tag(p)
                        }
                    }

                    Toggle(
                        prefs.language == .ja ? "中国火星座標系 (GCJ-02) 自動補正" : "自动执行火星坐标系 (GCJ-02) 轨迹纠偏",
                        isOn: $prefs.mapGCJ02Calibration
                    )
                    Text(prefs.language == .ja ? "スマート自動選択では、中国国内は高徳地図＋GCJ-02補正、海外はGoogleマップ＋WGS-84を自動適用します。" : "智能自动模式下：国内记录自动使用高德底图＋火星纠偏，海外记录自动使用谷歌地图＋物理真坐标，两全其美。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } header: {
                    Text(prefs.language == .ja ? "地図設定" : "地图与底图服务")
                        .font(.system(size: 11, weight: .bold))
                }

                // Section 4: AI Engine & Models
                Section {
                    Picker(prefs.language == .ja ? "AIサービス源" : "AI 服务商", selection: $prefs.aiProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.label(lang: prefs.language)).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)

                    if prefs.aiProvider == .deepseek {
                        // DeepSeek Config
                        LabeledContent("DeepSeek API Key") {
                            HStack(spacing: 8) {
                                if isShowingDeepSeekApiKey {
                                    TextField("sk-...", text: $prefs.deepseekApiKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                } else {
                                    SecureField("sk-...", text: $prefs.deepseekApiKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                }

                                Button {
                                    isShowingDeepSeekApiKey.toggle()
                                } label: {
                                    Image(systemName: isShowingDeepSeekApiKey ? "eye.slash" : "eye")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18)
                                }
                                .buttonStyle(.plain)
                                .help(isShowingDeepSeekApiKey ? (prefs.language == .ja ? "非表示" : "隐藏密钥") : (prefs.language == .ja ? "表示" : "显示明文"))
                            }
                        }

                        LabeledContent(prefs.language == .ja ? "APIエンドポイント (Base URL)" : "接入点 (Base URL)") {
                            TextField("", text: $prefs.deepseekBaseUrl)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))
                        }

                        LabeledContent(prefs.language == .ja ? "モデル選択" : "默认模型") {
                            HStack(spacing: 8) {
                                Picker("", selection: $prefs.deepseekModel) {
                                    ForEach(prefs.deepseekDiscoveredModels, id: \.self) { m in
                                        Text(formatDeepSeekModelLabel(m)).tag(m)
                                    }
                                }
                                .labelsHidden()

                                Button {
                                    triggerDeepSeekTest(prefs: prefs)
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(prefs.deepseekApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || deepseekConnectionState == .testing)
                                .help(prefs.language == .ja ? "モデルリストを再取得" : "向服务器刷新拉取支持的模型列表")
                            }
                        }

                        aiTestRow(
                            provider: "DeepSeek",
                            apiKey: prefs.deepseekApiKey,
                            state: deepseekConnectionState,
                            onTest: { triggerDeepSeekTest(prefs: prefs) }
                        )
                    } else {
                        // Gemini Config
                        LabeledContent("Gemini API Key") {
                            HStack(spacing: 8) {
                                if isShowingGeminiApiKey {
                                    TextField("AIzaSy...", text: $prefs.geminiApiKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                } else {
                                    SecureField("AIzaSy...", text: $prefs.geminiApiKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11.5, design: .monospaced))
                                }

                                Button {
                                    isShowingGeminiApiKey.toggle()
                                } label: {
                                    Image(systemName: isShowingGeminiApiKey ? "eye.slash" : "eye")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18)
                                }
                                .buttonStyle(.plain)
                                .help(isShowingGeminiApiKey ? (prefs.language == .ja ? "非表示" : "隐藏密钥") : (prefs.language == .ja ? "表示" : "显示明文"))
                            }
                        }

                        LabeledContent(prefs.language == .ja ? "APIエンドポイント (Base URL)" : "接入点 (Base URL)") {
                            TextField("", text: $prefs.geminiBaseUrl)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11.5, design: .monospaced))
                        }

                        LabeledContent(prefs.language == .ja ? "モデル選択" : "默认模型") {
                            HStack(spacing: 8) {
                                Picker("", selection: $prefs.geminiModel) {
                                    ForEach(prefs.geminiDiscoveredModels, id: \.self) { m in
                                        Text(formatGeminiModelLabel(m)).tag(m)
                                    }
                                }
                                .labelsHidden()

                                Button {
                                    triggerGeminiTest(prefs: prefs)
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(prefs.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || geminiConnectionState == .testing)
                                .help(prefs.language == .ja ? "モデルリストを再取得" : "向 Google 服务器刷新拉取支持的模型列表")
                            }
                        }

                        aiTestRow(
                            provider: "Gemini",
                            apiKey: prefs.geminiApiKey,
                            state: geminiConnectionState,
                            onTest: { triggerGeminiTest(prefs: prefs) }
                        )
                    }

                    Text(prefs.language == .ja ? "公式 0-Token 規格で検証するため、API残高は消費されません。モデル一覧も自動同期されます。キーはローカルにのみ保存されます。" : "探活采用各厂商官方 0-Token 标准通道，测试本身不扣除您的 API 额度，并会自动拉取云端支持的模型列表。密钥仅保存在本地设备。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                } header: {
                    HStack(spacing: 5) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 11))
                            .foregroundStyle(KazeTheme.vermilion)
                        Text(prefs.language == .ja ? "AI エンジンと大規模モデル" : "AI 引擎与大模型设置")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Text("KazeRun v1.0.0 (Garmin Studio)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(prefs.language == .ja ? "アカウント設定" : "账号与登录") {
                    dismiss()
                    appState.showAuthSheet = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(width: 580, height: 640)
    }

    private func triggerDeepSeekTest(prefs: UserPreferences) {
        Task {
            deepseekConnectionState = .testing
            let res = await DeepSeekService.shared.testConnection(
                apiKey: prefs.deepseekApiKey,
                baseUrl: prefs.deepseekBaseUrl,
                model: prefs.deepseekModel
            )
            deepseekConnectionState = res
            if case .success(_, let models) = res, !models.isEmpty {
                prefs.deepseekDiscoveredModels = models
                if !models.contains(prefs.deepseekModel) {
                    prefs.deepseekModel = models.first ?? "deepseek-chat"
                }
            }
        }
    }

    private func triggerGeminiTest(prefs: UserPreferences) {
        Task {
            geminiConnectionState = .testing
            let res = await GeminiService.shared.testConnection(
                apiKey: prefs.geminiApiKey,
                baseUrl: prefs.geminiBaseUrl,
                model: prefs.geminiModel
            )
            geminiConnectionState = res
            if case .success(_, let models) = res, !models.isEmpty {
                prefs.geminiDiscoveredModels = models
                if !models.contains(prefs.geminiModel) {
                    prefs.geminiModel = models.first ?? "gemini-2.5-flash"
                }
            }
        }
    }

    private func aiTestRow(provider: String, apiKey: String, state: AIConnectionState, onTest: @escaping () -> Void) -> some View {
        HStack {
            Button {
                onTest()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                    Text(state == .testing ? (appState.prefs.language == .ja ? "検証中..." : "正在探活...") : (appState.prefs.language == .ja ? "接続テスト" : "测试连接"))
                }
            }
            .buttonStyle(.bordered)
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state == .testing)

            Spacer()

            switch state {
            case .idle:
                Text(appState.prefs.language == .ja ? "Key入力後にテスト可能" : "输入 Key 后可一键验证可用性")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            case .testing:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(appState.prefs.language == .ja ? "\(provider) に接続中..." : "正在向 \(provider) 发起探活...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            case .success(let latency, let models):
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(KazeTheme.sage)
                    Text(appState.prefs.language == .ja
                        ? "接続成功 (\(latency)ms · \(models.count)モデル確認)"
                        : "连接成功 (延时 \(latency)ms\(models.isEmpty ? "" : " · 支持: \(models.prefix(2).joined(separator: ", "))\(models.count > 2 ? " 等 \(models.count) 款模型" : "")"))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(KazeTheme.sage)
                        .lineLimit(2)
                }
            case .failure(let error):
                HStack(spacing: 5) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(KazeTheme.vermilion)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(KazeTheme.vermilion)
                        .lineLimit(2)
                }
            }
        }
    }

    private func formatDeepSeekModelLabel(_ id: String) -> String {
        switch id {
        case "deepseek-flash":
            return "deepseek-flash (极速 · 默认推荐)"
        case "deepseek-v4-pro":
            return "deepseek-v4-pro (推理增强)"
        case "deepseek-chat":
            return "deepseek-chat (V3 通用)"
        case "deepseek-reasoner":
            return "deepseek-reasoner (R1 深度推理)"
        default:
            return id
        }
    }

    private func formatGeminiModelLabel(_ id: String) -> String {
        switch id {
        case "gemini-flash-latest":
            return "gemini-flash-latest (极速 · 默认推荐)"
        case "gemini-2.5-flash":
            return "gemini-2.5-flash (稳定极速)"
        case "gemini-2.5-pro":
            return "gemini-2.5-pro (深度推理)"
        case "gemini-2.0-flash":
            return "gemini-2.0-flash"
        default:
            return id
        }
    }
}
