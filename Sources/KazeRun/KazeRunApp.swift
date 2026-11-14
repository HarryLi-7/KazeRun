import SwiftUI

@main
struct KazeRunApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("KazeRun") {
            MainSplitView()
                .environment(appState)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .defaultSize(width: 1320, height: 840)

        MenuBarExtra {
            VStack(alignment: .leading, spacing: 6) {
                Text("KazeRun · Garmin")
                    .font(.headline)
                if let dash = appState.dashboard {
                    Text("HRV: \(KazeFormat.integer(dash.hrvData?.lastNightAvgHrvMs)) ms · RHR: \(dash.restingHRValue.map(String.init) ?? "--") bpm")
                    Text("VO2Max: \(dash.trainingStatus?.vo2MaxPrecise.map { String(format: "%.1f", $0) } ?? "--") · 电量: \(dash.stats?.bodyBatteryCurrent.map(String.init) ?? "--")")
                } else {
                    Text("尚未同步今日状态")
                }
                Divider()
                Button("立即同步") {
                    Task { await appState.syncAll() }
                }
                Button("退出 KazeRun") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(8)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "figure.run")
                if let hrv = appState.dashboard?.hrvData?.lastNightAvgHrvMs {
                    Text("\(Int(hrv))ms")
                }
            }
        }
    }
}
