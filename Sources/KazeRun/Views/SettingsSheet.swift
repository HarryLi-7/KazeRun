import SwiftUI

struct SettingsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

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
        .frame(width: 520, height: 480)
    }
}
