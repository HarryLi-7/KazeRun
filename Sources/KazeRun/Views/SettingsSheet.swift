import SwiftUI

struct SettingsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingApiKey: Bool = false
    @State private var connectionState: DeepSeekConnectionState = .idle

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

                // Section 4: AI & DeepSeek
                Section {
                    HStack {
                        Text(prefs.language == .ja ? "AIサービス源" : "AI 服务商")
                        Spacer()
                        Text("DeepSeek (深度求索)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    // API Key with Show/Hide toggle
                    LabeledContent("API Key") {
                        HStack(spacing: 8) {
                            if isShowingApiKey {
                                TextField("sk-...", text: $prefs.deepseekApiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11.5, design: .monospaced))
                            } else {
                                SecureField("sk-...", text: $prefs.deepseekApiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11.5, design: .monospaced))
                            }

                            Button {
                                isShowingApiKey.toggle()
                            } label: {
                                Image(systemName: isShowingApiKey ? "eye.slash" : "eye")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                            }
                            .buttonStyle(.plain)
                            .help(isShowingApiKey ? (prefs.language == .ja ? "非表示" : "隐藏密钥") : (prefs.language == .ja ? "表示" : "显示明文"))
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
                                    Text(formatModelLabel(m)).tag(m)
                                }
                            }
                            .labelsHidden()

                            Button {
                                Task {
                                    connectionState = .testing
                                    let res = await DeepSeekService.shared.testConnection(
                                        apiKey: prefs.deepseekApiKey,
                                        baseUrl: prefs.deepseekBaseUrl,
                                        model: prefs.deepseekModel
                                    )
                                    connectionState = res
                                    if case .success(_, let models) = res, !models.isEmpty {
                                        prefs.deepseekDiscoveredModels = models
                                        if !models.contains(prefs.deepseekModel) {
                                            prefs.deepseekModel = models.first ?? "deepseek-chat"
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(prefs.deepseekApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || connectionState == .testing)
                            .help(prefs.language == .ja ? "モデルリストを再取得" : "向服务器刷新拉取支持的模型列表")
                        }
                    }

                    // Test Connection Row
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Button {
                                Task {
                                    connectionState = .testing
                                    let res = await DeepSeekService.shared.testConnection(
                                        apiKey: prefs.deepseekApiKey,
                                        baseUrl: prefs.deepseekBaseUrl,
                                        model: prefs.deepseekModel
                                    )
                                    connectionState = res
                                    if case .success(_, let models) = res, !models.isEmpty {
                                        prefs.deepseekDiscoveredModels = models
                                        if !models.contains(prefs.deepseekModel) {
                                            prefs.deepseekModel = models.first ?? "deepseek-chat"
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "bolt.horizontal.circle.fill")
                                    Text(connectionState == .testing ? (prefs.language == .ja ? "検証中..." : "正在探活...") : (prefs.language == .ja ? "接続テスト" : "测试连接"))
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(prefs.deepseekApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || connectionState == .testing)

                            Spacer()

                            switch connectionState {
                            case .idle:
                                Text(prefs.language == .ja ? "Key入力後にテスト可能" : "输入 Key 后可一键验证可用性")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            case .testing:
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(prefs.language == .ja ? "DeepSeek に接続中..." : "正在向 DeepSeek 发起探活...")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            case .success(let latency, let models):
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(KazeTheme.sage)
                                    Text(prefs.language == .ja
                                        ? "接続成功 (\(latency)ms · \(models.count)モデル確認)"
                                        : "连接成功 (延时 \(latency)ms\(models.isEmpty ? "" : " · 已探明支持: \(models.joined(separator: ", "))"))")
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

                        Text(prefs.language == .ja ? "公式 0-Token 規格で検証するため、API残高は消費されません。モデル一覧も自動更新されます。" : "探活采用官方 0-Token 标准通道，测试本身不扣除您的 API 额度，并会自动拉取云端支持的模型列表。密钥仅保存在本地设备。")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
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
        .frame(width: 560, height: 620)
    }

    private func formatModelLabel(_ id: String) -> String {
        switch id {
        case "deepseek-chat":
            return "deepseek-chat (V3 · 默认推荐)"
        case "deepseek-reasoner":
            return "deepseek-reasoner (R1 · 深度推理)"
        default:
            return id
        }
    }
}
