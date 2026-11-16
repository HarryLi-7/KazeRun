import SwiftUI

struct MainSplitView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            topStudioNavBar
            Divider()

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KazeTheme.canvas)
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

    private var topStudioNavBar: some View {
        HStack(spacing: 16) {
            // Brand Logo & Studio Subtitle
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(KazeTheme.vermilion)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "figure.run")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 0) {
                    Text("KazeRun")
                        .font(.system(size: 14, weight: .bold))
                    Text("GARMIN STUDIO")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Center Segmented Navigation Pills
            HStack(spacing: 3) {
                ForEach(SidebarTab.allCases) { tab in
                    let isSelected = appState.selectedTab == tab
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            appState.selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? KazeTheme.vermilion : Color.secondary)
                            Text(tab.localizedTitle(lang: appState.prefs.language))
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5.5)
                        .background(
                            Group {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(KazeTheme.surface)
                                        .shadow(color: Color.black.opacity(0.06), radius: 2, y: 1)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .stroke(KazeTheme.hairline, lineWidth: 1)
                                        )
                                }
                            }
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(KazeTheme.surfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(KazeTheme.hairline, lineWidth: 1)
            )

            Spacer()

            // Right Actions: Account, Settings, Sync
            HStack(spacing: 8) {
                Button {
                    appState.showAuthSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 13))
                        Text(appState.authStatus?.authenticated == true
                            ? (appState.prefs.language == .ja ? "アカウント" : "账号")
                            : (appState.prefs.language == .ja ? "ログイン" : "登录"))
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.bordered)

                Button {
                    appState.showSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .padding(5)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(",", modifiers: .command)
                .help("偏好设置 (⌘,)")

                SyncToolbarButton()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(KazeTheme.surface)
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
        .buttonStyle(.bordered)
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
