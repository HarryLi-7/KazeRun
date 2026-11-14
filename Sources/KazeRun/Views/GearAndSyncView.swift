import SwiftUI

struct GearAndSyncView: View {
    @Environment(AppState.self) private var appState
    @State private var cacheSize: String = "--"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EQUIPMENT & ENGINE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(KazeTheme.vermilion)
                    Text("跑鞋装备、设备与同步诊断")
                        .font(.system(size: 22, weight: .bold))
                }

                // Gear Grid
                KazeCard {
                    KazeSectionHeader(
                        jpTag: "SHOES",
                        title: "跑鞋里程追踪",
                        subtitle: "\(appState.dashboard?.gear?.gear?.count ?? 0) 双在役"
                    )
                    let gearList = appState.dashboard?.gear?.gear ?? []
                    if gearList.isEmpty {
                        Text("暂无装备数据").font(.caption).foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                            ForEach(gearList) { item in
                                let used = item.stats?.totalDistanceKm ?? 0
                                let maxKm = item.maxDistanceKm ?? 800
                                let pct = min(1.0, maxKm > 0 ? used / maxKm : 0)
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.displayTitle)
                                            .font(.system(size: 13, weight: .semibold))
                                        Spacer()
                                        if let defs = item.isDefaultFor, !defs.isEmpty {
                                            Text("默认")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(KazeTheme.vermilion)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(KazeTheme.vermilion.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }

                                    ProgressView(value: pct)
                                        .tint(pct > 0.85 ? KazeTheme.amber : KazeTheme.sage)

                                    HStack {
                                        Text(String(format: "%.1f / %.0f km", used, maxKm))
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        Spacer()
                                        Text("\(item.stats?.totalActivities ?? 0) 次活动")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(12)
                                .background(KazeTheme.surfaceSubtle)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }

                // Devices
                KazeCard {
                    KazeSectionHeader(jpTag: "WATCH", title: "关联设备与最近同步")
                    if let last = appState.dashboard?.deviceLastUsed {
                        HStack(spacing: 20) {
                            KazeMetricBadge(label: "主力设备", value: last.deviceName ?? "--")
                            KazeMetricBadge(label: "设备 ID", value: last.userDeviceId.map(String.init) ?? "--")
                            KazeMetricBadge(label: "最近上传", value: last.lastUploadTime ?? "--")
                        }
                    }
                    let devs = appState.dashboard?.devices ?? []
                    ForEach(devs) { d in
                        HStack {
                            Text(d.deviceName ?? "设备")
                                .font(.system(size: 13, weight: .semibold))
                            Text("固件 \(d.softwareVersion ?? "--")")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(d.status ?? "")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(KazeTheme.sage)
                        }
                        .padding(.top, 4)
                    }
                }

                // Account & Runtime Diagnostics (Portable Verification)
                KazeCard {
                    KazeSectionHeader(jpTag: "RUNTIME", title: "账号、本地缓存与跨机运行状态")
                    VStack(alignment: .leading, spacing: 8) {
                        infoRow("当前账号", appState.authStatus?.displayName ?? appState.authStatus?.email ?? "未登录")
                        infoRow("账号区域", (appState.authStatus?.isCn ?? true) ? "中国区 (garmin.cn)" : "国际区 (garmin.com)")
                        infoRow("桥接运行模式", appState.runtimeMode)
                        infoRow("Token 目录", appState.authStatus?.tokenDir ?? "--")
                        infoRow("本地缓存大小", cacheSize)
                    }

                    HStack(spacing: 10) {
                        Button("重新登录 / 切换账号") {
                            appState.showAuthSheet = true
                        }
                        .buttonStyle(.bordered)

                        Button("清空本地缓存") {
                            appState.cache.clearAll()
                            cacheSize = appState.cache.cacheSizeDescription()
                            appState.setBanner("本地缓存已清空，可点击右上角重新同步。", isError: false)
                        }
                        .buttonStyle(.bordered)

                        Button("退出当前账号", role: .destructive) {
                            Task {
                                _ = try? await appState.bridge.callDictionary(method: "auth_logout")
                                await appState.refreshAuthStatus()
                                appState.showAuthSheet = true
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(20)
        }
        .background(KazeTheme.canvas)
        .onAppear {
            cacheSize = appState.cache.cacheSizeDescription()
        }
    }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
        }
    }
}
