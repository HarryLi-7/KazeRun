import SwiftUI

struct MainSplitView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(KazeTheme.vermilion)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "figure.run")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        )
                    VStack(alignment: .leading, spacing: 0) {
                        Text("KazeRun")
                            .font(.system(size: 14, weight: .bold))
                        Text("GARMIN STUDIO")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

                List(SidebarTab.allCases, selection: $state.selectedTab) { tab in
                    HStack(spacing: 10) {
                        Image(systemName: tab.icon)
                            .frame(width: 18)
                            .foregroundStyle(state.selectedTab == tab ? KazeTheme.vermilion : .secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tab.localizedTitle(lang: appState.prefs.language))
                                .font(.system(size: 13, weight: state.selectedTab == tab ? .semibold : .regular))
                                .lineLimit(1)
                            Text(tab.jpLabel)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(tab)
                }
                .listStyle(.sidebar)

            }
            .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
        } detail: {
            VStack(spacing: 0) {
                if let msg = appState.bannerMessage {
                    HStack(spacing: 10) {
                        Image(systemName: appState.bannerIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(appState.bannerIsError ? KazeTheme.vermilion : KazeTheme.sage)
                        Text(msg)
                            .font(.system(size: 12))
                        Spacer()
                        Button(appState.prefs.language == .ja ? "閉じる" : "关闭") { appState.clearBanner() }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(appState.bannerIsError ? KazeTheme.vermilion.opacity(0.08) : KazeTheme.sage.opacity(0.08))
                    Divider()
                }

                switch appState.selectedTab {
                case .today:
                    TodayDashboardView()
                case .activities:
                    ActivitiesView()
                case .trends:
                    TrendsView()
                case .studio:
                    WorkoutStudioView()
                case .gearSync:
                    GearAndSyncView()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        appState.showSettingsSheet = true
                    } label: {
                        Label(appState.prefs.language == .ja ? "設定" : "设置", systemImage: "gearshape")
                    }
                    .keyboardShortcut(",", modifiers: .command)

                    Button {
                        appState.showAuthSheet = true
                    } label: {
                        Label(
                            appState.authStatus?.authenticated == true ? (appState.prefs.language == .ja ? "アカウント" : "账号") : (appState.prefs.language == .ja ? "ログイン" : "登录"),
                            systemImage: "person.crop.circle"
                        )
                    }

                    SyncToolbarButton()
                }
            }
        }
        .preferredColorScheme(appState.prefs.appearance.colorScheme)
        .sheet(isPresented: $state.showAuthSheet) {
            AuthSheet()
                .environment(appState)
        }
        .sheet(isPresented: $state.showSettingsSheet) {
            SettingsSheet()
                .environment(appState)
        }
        .task {
            await appState.bootstrap()
        }
    }
}

/// Dynamic Toolbar Sync Button: turns Vermilion & spins whenever ANY loading/syncing occurs!
struct SyncToolbarButton: View {
    @Environment(AppState.self) private var appState
    @State private var isSpinning: Bool = false

    var body: some View {
        Button {
            Task { await appState.syncAll() }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: appState.isAnyLoading ? .bold : .medium))
                .foregroundStyle(appState.isAnyLoading ? KazeTheme.vermilion : Color.secondary)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
        }
        .tint(appState.isAnyLoading ? KazeTheme.vermilion : nil)
        .help(
            appState.isAnyLoading
                ? (appState.prefs.language == .ja ? "データを読み込み・同期中..." : "正在加载与同步数据...")
                : (appState.prefs.language == .ja ? "全同期 (⌘R)" : "全量同步 (⌘R)")
        )
        .keyboardShortcut("r", modifiers: .command)
        .disabled(appState.isAnyLoading)
        .onChange(of: appState.isAnyLoading, initial: true) { _, loading in
            if loading {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    isSpinning = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    isSpinning = false
                }
            }
        }
    }
}
