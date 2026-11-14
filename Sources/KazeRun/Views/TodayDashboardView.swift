import SwiftUI
import Charts

struct TodayDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var showDatePickerPopover: Bool = false
    @State private var hoveredOvernightIndex: Int? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerBar

                if let dash = appState.dashboard {
                    readinessRow(dash)
                    trainingAndLoadRow(dash)
                    raceAndDailyRow(dash)
                    scheduleRow(dash)
                } else if appState.isSyncingDashboard {
                    KazeCard {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(appState.prefs.language == .ja ? "Garmin Connect から最新データを同期中..." : "正在从 Garmin Connect 同步今日数据与训练状态...")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 24)
                    }
                } else {
                    KazeCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(appState.prefs.language == .ja ? "キャッシュデータがありません" : "尚无今日缓存数据")
                                .font(.headline)
                            Text(appState.prefs.language == .ja ? "右上の「同期」をクリックして Garmin から最新の睡眠・HRV・負荷を取得してください。" : "点击右上角「同步」即可通过 Garmin MCP 拉取今日睡眠、HRV、训练负荷、课表与活动。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button(appState.prefs.language == .ja ? "今すぐ同期" : "立即同步") {
                                Task { await appState.syncAll() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(KazeTheme.vermilion)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(KazeTheme.canvas)
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CONDITION & READINESS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(KazeTheme.vermilion)
                Text(appState.prefs.language == .ja ? "コンディションとトレーニング負荷" : "今日状态与训练负荷")
                    .font(.system(size: 22, weight: .bold))
            }
            Spacer()
            dateSelector
        }
    }

    private var dateSelector: some View {
        HStack(spacing: 8) {
            // Jump to today button if viewing historical date
            if !Calendar.current.isDateInToday(appState.selectedDate) {
                Button {
                    appState.resetToToday()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .bold))
                        Text(appState.prefs.language == .ja ? "今日に戻る" : "回到今天")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(KazeTheme.vermilion.opacity(0.12))
                    .foregroundStyle(KazeTheme.vermilion)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Stepper previous day
            Button {
                if let prevDay = Calendar.current.date(byAdding: .day, value: -1, to: appState.selectedDate) {
                    appState.selectDate(prevDay)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(KazeTheme.surfaceSubtle)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(appState.prefs.language == .ja ? "前日" : "前一天")

            // Main Date Pill (Click to open non-clipping Graphical Calendar Popover)
            Button {
                showDatePickerPopover = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(KazeTheme.vermilion)
                    Text(dateDisplayTitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(KazeTheme.surfaceSubtle)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDatePickerPopover, arrowEdge: .bottom) {
                VStack(spacing: 12) {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { appState.selectedDate },
                            set: { newDate in
                                appState.selectDate(newDate)
                                showDatePickerPopover = false
                            }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(8)

                    HStack {
                        Button(appState.prefs.language == .ja ? "今日を選択" : "选择今天") {
                            appState.resetToToday()
                            showDatePickerPopover = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(KazeTheme.vermilion)
                        .font(.system(size: 12))

                        Spacer()

                        Button(appState.prefs.language == .ja ? "閉じる" : "关闭") {
                            showDatePickerPopover = false
                        }
                        .buttonStyle(.bordered)
                        .font(.system(size: 12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .frame(width: 290)
            }

            // Stepper next day (disabled if today)
            Button {
                if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: appState.selectedDate),
                   nextDay <= Date() {
                    appState.selectDate(nextDay)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(KazeTheme.surfaceSubtle)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(Calendar.current.isDateInToday(appState.selectedDate))
            .opacity(Calendar.current.isDateInToday(appState.selectedDate) ? 0.35 : 1.0)
            .help(appState.prefs.language == .ja ? "翌日" : "后一天")
        }
    }

    private var dateDisplayTitle: String {
        let isToday = Calendar.current.isDateInToday(appState.selectedDate)
        let isYesterday = Calendar.current.isDateInYesterday(appState.selectedDate)

        let formatter = DateFormatter()
        formatter.locale = appState.prefs.language == .ja ? Locale(identifier: "ja_JP") : Locale(identifier: "zh_CN")
        formatter.dateFormat = appState.prefs.language == .ja ? "yyyy年M月d日 (E)" : "yyyy年M月d日 EEE"
        let baseStr = formatter.string(from: appState.selectedDate)

        if isToday {
            return "\(baseStr) · " + (appState.prefs.language == .ja ? "今日" : "今天")
        } else if isYesterday {
            return "\(baseStr) · " + (appState.prefs.language == .ja ? "昨日" : "昨天")
        }
        return baseStr
    }

    @ViewBuilder
    private func readinessRow(_ dash: DashboardSnapshot) -> some View {
        ViewThatFits(in: .horizontal) {
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow {
                    hrvCard(dash, fillHeight: true).frame(minWidth: 230)
                    sleepCard(dash, fillHeight: true).frame(minWidth: 230)
                    bodyCard(dash, fillHeight: true).frame(minWidth: 230)
                }
            }
            VStack(spacing: 14) {
                hrvCard(dash)
                sleepCard(dash)
                bodyCard(dash)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func hrvCard(_ dash: DashboardSnapshot, fillHeight: Bool = false) -> some View {
        let readings = (dash.hrvData?.hrvReadings ?? []).filter { ($0.hrvMs ?? 0) > 0 }
        let hoveredReading = hoveredOvernightIndex.flatMap { idx in
            (idx >= 0 && idx < readings.count) ? readings[idx] : nil
        }
        let displayVal = hoveredReading?.hrvMs ?? dash.hrvData?.lastNightAvgHrvMs

        return KazeCard(fillHeight: fillHeight) {
            KazeSectionHeader(
                jpTag: "HRV",
                title: appState.prefs.language == .ja ? "夜間心拍変動" : "夜间心率变异性",
                subtitle: KazeI18n.hrvStatus(dash.hrvData?.status, lang: appState.prefs.language)
            )
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(KazeFormat.integer(displayVal))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .fixedSize()
                Text("ms")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                if let hr = hoveredReading {
                    Text(String(hr.time.suffix(10).prefix(5)))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(KazeTheme.vermilion)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(KazeTheme.vermilion.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()
                if let low = dash.hrvData?.baselineBalancedLowMs,
                   let high = dash.hrvData?.baselineBalancedUpperMs {
                    Text(appState.prefs.language == .ja ? "基準 \(Int(low))–\(Int(high))" : "基线 \(Int(low))–\(Int(high))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(KazeTheme.sage)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(KazeTheme.sage.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // HRV Chart Section (夜间心率变异性图表，支持鼠标悬停检视点位)
            hrvChart(dash, readings: readings)

            HStack(spacing: 16) {
                KazeMetricBadge(
                    label: appState.prefs.language == .ja ? "7日平均" : "7日均值",
                    value: KazeFormat.integer(dash.hrvData?.weeklyAvgHrvMs),
                    unit: "ms"
                )
                KazeMetricBadge(
                    label: appState.prefs.language == .ja ? "5分最高" : "5分峰值",
                    value: KazeFormat.integer(dash.hrvData?.lastNight5MinHighHrvMs),
                    unit: "ms"
                )
            }
        }
    }

    @ViewBuilder
    private func hrvChart(_ dash: DashboardSnapshot, readings: [HRVReading]) -> some View {
        let low = dash.hrvData?.baselineBalancedLowMs ?? 70
        let high = dash.hrvData?.baselineBalancedUpperMs ?? 110
        let avg = dash.hrvData?.lastNightAvgHrvMs
        let isBalanced = dash.hrvData?.status?.uppercased() == "BALANCED"
        let chartColor = isBalanced ? KazeTheme.sage : KazeTheme.vermilion

        if !readings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Chart {
                    // Shaded baseline range
                    RectangleMark(
                        yStart: .value("Baseline Low", low),
                        yEnd: .value("Baseline High", high)
                    )
                    .foregroundStyle(KazeTheme.sage.opacity(0.14))

                    RuleMark(y: .value("Baseline Low", low))
                        .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                        .foregroundStyle(KazeTheme.sage.opacity(0.45))

                    RuleMark(y: .value("Baseline High", high))
                        .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                        .foregroundStyle(KazeTheme.sage.opacity(0.45))

                    // Overnight Average dashed line
                    if let avg, avg > 0 {
                        RuleMark(y: .value("Average", avg))
                            .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [4, 3]))
                            .foregroundStyle(chartColor.opacity(0.75))
                    }

                    // Overnight 5-minute readings
                    ForEach(Array(readings.enumerated()), id: \.offset) { idx, r in
                        if let ms = r.hrvMs {
                            AreaMark(
                                x: .value("Point", idx),
                                y: .value("HRV", ms)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [chartColor.opacity(0.25), chartColor.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Point", idx),
                                y: .value("HRV", ms)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(chartColor)
                        }
                    }

                    // Hover indicator
                    if let hIdx = hoveredOvernightIndex, hIdx < readings.count, let ms = readings[hIdx].hrvMs {
                        RuleMark(x: .value("Point", hIdx))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                            .foregroundStyle(KazeTheme.vermilion.opacity(0.85))

                        PointMark(
                            x: .value("Point", hIdx),
                            y: .value("HRV", ms)
                        )
                        .foregroundStyle(KazeTheme.vermilion)
                        .symbolSize(36)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: min(10, (readings.compactMap { $0.hrvMs }.min() ?? low) - 5) ... max(high + 15, (readings.compactMap { $0.hrvMs }.max() ?? high) + 5))
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let loc):
                                    if let idx: Int = proxy.value(atX: loc.x) {
                                        hoveredOvernightIndex = max(0, min(readings.count - 1, idx))
                                    } else {
                                        hoveredOvernightIndex = nil
                                    }
                                case .ended:
                                    hoveredOvernightIndex = nil
                                }
                            }
                    }
                }
                .frame(height: 52)

                if let hIdx = hoveredOvernightIndex, hIdx < readings.count, let ms = readings[hIdx].hrvMs {
                    let time = String(readings[hIdx].time.suffix(10).prefix(5))
                    let isWithin = ms >= low && ms <= high
                    HStack(spacing: 6) {
                        Text("🕒 \(time)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Text("\(Int(ms)) ms")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(isWithin ? KazeTheme.sage : KazeTheme.vermilion)
                        Text(isWithin ? (appState.prefs.language == .ja ? "基準内" : "基线内") : (appState.prefs.language == .ja ? "基準外" : "基线外"))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(isWithin ? KazeTheme.sage : KazeTheme.vermilion)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background((isWithin ? KazeTheme.sage : KazeTheme.vermilion).opacity(0.12))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    .frame(height: 14)
                } else {
                    HStack {
                        if let firstTime = readings.first?.time.suffix(10).prefix(5) {
                            Text(String(firstTime))
                        } else {
                            Text("入睡")
                        }
                        Spacer()
                        Text(appState.prefs.language == .ja ? "夜間5分サンプリング" : "夜间 5 分钟采样")
                            .font(.system(size: 9))
                        Spacer()
                        if let lastTime = readings.last?.time.suffix(10).prefix(5) {
                            Text(String(lastTime))
                        } else {
                            Text("醒来")
                        }
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(height: 14)
                }
            }
            .padding(.vertical, 3)
        } else if let trend = dash.hrvTrend?.trend, !trend.isEmpty {
            let recent = Array(trend.suffix(7))
            VStack(alignment: .leading, spacing: 4) {
                Chart {
                    RectangleMark(
                        yStart: .value("Baseline Low", low),
                        yEnd: .value("Baseline High", high)
                    )
                    .foregroundStyle(KazeTheme.sage.opacity(0.14))

                    ForEach(recent) { p in
                        if let v = p.lastNightAvgHrvMs {
                            BarMark(
                                x: .value("Date", String(p.date.suffix(5))),
                                y: .value("HRV", v)
                            )
                            .foregroundStyle(p.status?.uppercased() == "BALANCED" ? KazeTheme.sage : KazeTheme.vermilion)
                            .cornerRadius(2)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) {
                        AxisValueLabel()
                            .font(.system(size: 8, design: .monospaced))
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 52)

                Text(appState.prefs.language == .ja ? "直近7日間の推移" : "近期 7 日 HRV")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 3)
        } else {
            hrvBaselineGauge(avg: avg, low: low, high: high, color: chartColor)
                .frame(height: 20)
                .padding(.vertical, 4)
        }
    }

    private func hrvBaselineGauge(avg: Double?, low: Double, high: Double, color: Color) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let maxVal = max(high * 1.3, (avg ?? 0) * 1.2, 120)
            let lowX = w * (low / maxVal)
            let highX = w * (high / maxVal)
            let currentX = avg.map { min(w, max(0, w * ($0 / maxVal))) } ?? 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(KazeTheme.surfaceSubtle)
                    .frame(height: 6)

                // Baseline range
                RoundedRectangle(cornerRadius: 3)
                    .fill(KazeTheme.sage.opacity(0.25))
                    .frame(width: max(0, highX - lowX), height: 10)
                    .offset(x: lowX)

                // Indicator needle
                if avg != nil {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .shadow(color: color.opacity(0.3), radius: 2)
                        .offset(x: max(0, currentX - 5))
                }
            }
        }
    }

    private func sleepCard(_ dash: DashboardSnapshot, fillHeight: Bool = false) -> some View {
        KazeCard(fillHeight: fillHeight) {
            KazeSectionHeader(
                jpTag: "SLEEP",
                title: appState.prefs.language == .ja ? "睡眠回復" : "睡眠恢复",
                subtitle: sleepQualifier(dash.sleepSummary?.sleepScoreQualifier)
            )
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(KazeFormat.duration(dash.sleepSummary?.sleepSeconds))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .fixedSize()
                Spacer()
                if let score = dash.sleepSummary?.sleepScore {
                    Text(appState.prefs.language == .ja ? "スコア \(score)" : "评分 \(score)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(score >= 80 ? KazeTheme.sage : KazeTheme.amber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((score >= 80 ? KazeTheme.sage : KazeTheme.amber).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            sleepBar(dash.sleepSummary)
        }
    }

    private func bodyCard(_ dash: DashboardSnapshot, fillHeight: Bool = false) -> some View {
        KazeCard(fillHeight: fillHeight) {
            KazeSectionHeader(
                jpTag: "BODY",
                title: appState.prefs.language == .ja ? "安静時心拍とバッテリー" : "静息心率与电量"
            )
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.prefs.language == .ja ? "安静時心拍" : "静息心率")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(dash.restingHRValue.map(String.init) ?? "--")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(KazeTheme.vermilion)
                            .fixedSize()
                        Text("bpm")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.prefs.language == .ja ? "ボディバッテリー" : "当前身体电量")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(dash.stats?.bodyBatteryCurrent.map(String.init) ?? "--")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(KazeTheme.indigo)
                            .fixedSize()
                        Text("/ 100")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HStack(spacing: 16) {
                KazeMetricBadge(
                    label: appState.prefs.language == .ja ? "充電" : "充电",
                    value: "+\(dash.stats?.bodyBatteryCharged ?? dash.bodyBattery?.first?.charged ?? 0)",
                    tone: KazeTheme.sage
                )
                KazeMetricBadge(
                    label: appState.prefs.language == .ja ? "消費" : "消耗",
                    value: "-\(dash.stats?.bodyBatteryDrained ?? dash.bodyBattery?.first?.drained ?? 0)",
                    tone: KazeTheme.amber
                )
                KazeMetricBadge(
                    label: appState.prefs.language == .ja ? "7日平均RHR" : "7日RHR",
                    value: KazeFormat.integer(dash.stats?.last7DaysAvgRestingHr),
                    unit: "bpm"
                )
            }
        }
    }

    @ViewBuilder
    private func sleepBar(_ sleep: SleepSummary?) -> some View {
        let deep = sleep?.deepSleepPercent ?? 0
        let light = sleep?.lightSleepPercent ?? 0
        let rem = sleep?.remSleepPercent ?? 0
        let total = max(1, deep + light + rem)
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Rectangle().fill(KazeTheme.indigo)
                        .frame(width: geo.size.width * (deep / total))
                    Rectangle().fill(KazeTheme.indigo.opacity(0.4))
                        .frame(width: geo.size.width * (light / total))
                    Rectangle().fill(KazeTheme.sage)
                        .frame(width: geo.size.width * (rem / total))
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)

            HStack(spacing: 12) {
                Text("\(appState.prefs.language == .ja ? "深い" : "深") \(Int(deep.rounded()))%").foregroundStyle(KazeTheme.indigo)
                Text("\(appState.prefs.language == .ja ? "浅い" : "浅") \(Int(light.rounded()))%").foregroundStyle(.secondary)
                Text("REM \(Int(rem.rounded()))%").foregroundStyle(KazeTheme.sage)
            }
            .font(.system(size: 11, design: .monospaced))
        }
    }

    @ViewBuilder
    private func trainingAndLoadRow(_ dash: DashboardSnapshot) -> some View {
        ViewThatFits(in: .horizontal) {
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow {
                    statusCard(dash, fillHeight: true).frame(minWidth: 340)
                    loadCard(dash, fillHeight: true).frame(minWidth: 340)
                }
            }
            VStack(spacing: 14) {
                statusCard(dash)
                loadCard(dash)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func statusCard(_ dash: DashboardSnapshot, fillHeight: Bool = false) -> some View {
        KazeCard(fillHeight: fillHeight) {
            KazeSectionHeader(
                jpTag: "STATUS",
                title: appState.prefs.language == .ja ? "トレーニングステータス" : "训练状态与 ACWR"
            )
            if let device = dash.trainingStatus?.reportingDeviceName {
                Text(device).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(KazeI18n.trainingStatus(dash.trainingStatus?.trainingStatusFeedback, lang: appState.prefs.language))
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                        .fixedSize()
                    if let ratio = dash.trainingStatus?.loadRatio {
                        Text(String(format: appState.prefs.language == .ja ? "負荷比 %.2f · %@" : "负荷比 %.2f · %@", ratio, acwrStatus(dash.trainingStatus?.acwrStatus)))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(KazeTheme.sage)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                HStack(spacing: 18) {
                KazeMetricBadge(
                    label: "VO2Max",
                    value: dash.trainingStatus?.vo2MaxPrecise.map { String(format: "%.1f", $0) } ?? "--",
                    tone: KazeTheme.vermilion
                )
                KazeMetricBadge(
                    label: appState.prefs.language == .ja ? "急性負荷" : "急性负荷",
                    value: KazeFormat.integer(dash.trainingStatus?.acuteLoad)
                )
                KazeMetricBadge(
                    label: appState.prefs.language == .ja ? "慢性負荷" : "慢性负荷",
                    value: KazeFormat.integer(dash.trainingStatus?.chronicLoad)
                )
                }
            }
        }
    }

    private func loadCard(_ dash: DashboardSnapshot, fillHeight: Bool = false) -> some View {
        KazeCard(fillHeight: fillHeight) {
            KazeSectionHeader(
                jpTag: "LOAD",
                title: appState.prefs.language == .ja ? "月間負荷バランス" : "月度负荷平衡",
                subtitle: KazeI18n.loadBalanceFeedback(dash.trainingLoadBalance?.feedback, lang: appState.prefs.language)
            )
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Circle().fill(Color.secondary).frame(width: 6, height: 6)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    Capsule().fill(Color.secondary).frame(width: 10, height: 4)
                    Text(appState.prefs.language == .ja ? "現在の負荷" : "当前负荷")
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.15)))
                        .frame(width: 14, height: 10)
                    Text(appState.prefs.language == .ja ? "目標範囲" : "目标区间")
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            VStack(spacing: 10) {
                loadBandRow(title: appState.prefs.language == .ja ? "低有酸素" : "低有氧", band: dash.trainingLoadBalance?.aerobicLow, color: KazeTheme.indigo)
                loadBandRow(title: appState.prefs.language == .ja ? "高有酸素" : "高有氧", band: dash.trainingLoadBalance?.aerobicHigh, color: KazeTheme.sage)
                loadBandRow(title: appState.prefs.language == .ja ? "無酸素" : "无氧", band: dash.trainingLoadBalance?.anaerobic, color: KazeTheme.vermilion)
            }
        }
    }

    private func loadBandRow(title: String, band: LoadBand?, color: Color) -> some View {
        let load = band?.load.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        let target: ClosedRange<Double>? = {
            guard let low = band?.targetMin, let high = band?.targetMax,
                  low.isFinite, high.isFinite, low >= 0, high > low else { return nil }
            return low...high
        }()
        let scale = max(load ?? 0, target?.upperBound ?? 0, 1) * 1.05

        let status = band?.status?.lowercased() ?? ""
        let isWithin = status == "within" || (target != nil && load != nil && target!.contains(load!))
        let isBelow = status == "below" || (target != nil && load != nil && load! < target!.lowerBound)
        let isAbove = status == "above" || (target != nil && load != nil && load! > target!.upperBound)

        let statusColor: Color = isWithin ? KazeTheme.sage : (isBelow ? KazeTheme.vermilion : KazeTheme.amber)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                Text(title).font(.system(size: 12, weight: .semibold))

                // Pure visual status badge (no extra text)
                if isWithin {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(KazeTheme.sage)
                } else if isBelow {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(KazeTheme.vermilion)
                } else if isAbove {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(KazeTheme.amber)
                }

                Spacer()

                Text(load.map { String(format: "%.0f", $0) } ?? "--")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))

                Text(loadStatus(band?.status))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            GeometryReader { geo in
                let w = geo.size.width
                let targetX = target.map { w * $0.lowerBound / scale } ?? 0
                let targetW = target.map { w * ($0.upperBound - $0.lowerBound) / scale } ?? 0
                let loadW = load.map { min(w, w * $0 / scale) } ?? 0

                ZStack(alignment: .leading) {
                    // Base background channel
                    Capsule()
                        .fill(KazeTheme.surfaceSubtle)
                        .frame(height: 8)

                    // Target Bracket Box (明确的达标靶位框)
                    if target != nil, targetW > 0 {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isWithin ? color.opacity(0.18) : Color.secondary.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(isWithin ? color.opacity(0.65) : Color.secondary.opacity(0.40), lineWidth: 1)
                                )

                            // Target boundary tick marks (左右门柱刻度线)
                            HStack {
                                Rectangle()
                                    .fill(isWithin ? color : Color.secondary.opacity(0.6))
                                    .frame(width: 1.5, height: 14)
                                Spacer()
                                Rectangle()
                                    .fill(isWithin ? color : Color.secondary.opacity(0.6))
                                    .frame(width: 1.5, height: 14)
                            }
                        }
                        .frame(width: targetW, height: 14)
                        .offset(x: targetX)
                    }

                    // Dashed shortfall gap (未达成时，从当前位置到目标区间的虚线引导线)
                    if isBelow, target != nil, targetX > loadW {
                        Path { path in
                            path.move(to: CGPoint(x: max(4, loadW), y: 7))
                            path.addLine(to: CGPoint(x: targetX, y: 7))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                        .foregroundStyle(color.opacity(0.6))
                    }

                    // Current Load Bar with Pin Needle Head
                    if let load, load > 0 {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [color.opacity(0.75), color],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(6, loadW), height: 6)

                            // Indicator Needle Pin at current load position
                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                .shadow(color: color.opacity(0.4), radius: 2, x: 0, y: 1)
                                .offset(x: max(0, loadW - 5))
                        }
                    }
                }
            }
            .frame(height: 16)
            Text(target.map { String(format: appState.prefs.language == .ja ? "目標 %.0f–%.0f" : "目标 %.0f–%.0f", $0.lowerBound, $0.upperBound) }
                 ?? (appState.prefs.language == .ja ? "目標範囲 --" : "目标区间 --"))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func loadStatus(_ raw: String?) -> String {
        switch raw?.lowercased() {
        case "below": return appState.prefs.language == .ja ? "目標未満" : "低于目标"
        case "within": return appState.prefs.language == .ja ? "目標内" : "目标内"
        case "above": return appState.prefs.language == .ja ? "目標超過" : "高于目标"
        default: return raw ?? "--"
        }
    }

    private func sleepQualifier(_ raw: String?) -> String {
        switch raw?.uppercased() {
        case "EXCELLENT": return appState.prefs.language == .ja ? "優秀" : "极佳"
        case "GOOD": return appState.prefs.language == .ja ? "良好" : "良好"
        case "FAIR": return appState.prefs.language == .ja ? "普通" : "一般"
        case "POOR": return appState.prefs.language == .ja ? "不良" : "较差"
        default: return raw ?? "--"
        }
    }

    private func acwrStatus(_ raw: String?) -> String {
        switch raw?.uppercased() {
        case "OPTIMAL": return appState.prefs.language == .ja ? "最適" : "最佳"
        case "LOW": return appState.prefs.language == .ja ? "低い" : "偏低"
        case "HIGH": return appState.prefs.language == .ja ? "高い" : "偏高"
        default: return raw ?? "--"
        }
    }

    @ViewBuilder
    private func raceAndDailyRow(_ dash: DashboardSnapshot) -> some View {
        ViewThatFits(in: .horizontal) {
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow {
                    predictionCard(dash, fillHeight: true).frame(minWidth: 340)
                    dailyCard(dash, fillHeight: true).frame(minWidth: 340)
                }
            }
            VStack(spacing: 14) {
                predictionCard(dash)
                dailyCard(dash)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func predictionCard(_ dash: DashboardSnapshot, fillHeight: Bool = false) -> some View {
        KazeCard(fillHeight: fillHeight) {
            KazeSectionHeader(
                jpTag: "PREDICT",
                title: appState.prefs.language == .ja ? "Garmin レース予想タイム" : "佳明完赛预测",
                subtitle: dash.racePredictions?.predictionDate
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 10)], alignment: .leading, spacing: 10) {
                predictionPill("5K", dash.racePredictions?.predictions?["5K"]?.time)
                predictionPill("10K", dash.racePredictions?.predictions?["10K"]?.time)
                predictionPill(appState.prefs.language == .ja ? "ハーフ" : "半马", dash.racePredictions?.predictions?["half_marathon"]?.time)
                predictionPill(appState.prefs.language == .ja ? "フル" : "全马", dash.racePredictions?.predictions?["marathon"]?.time)
            }
        }
    }

    private func dailyCard(_ dash: DashboardSnapshot, fillHeight: Bool = false) -> some View {
        KazeCard(fillHeight: fillHeight) {
            KazeSectionHeader(
                jpTag: "DAILY",
                title: appState.prefs.language == .ja ? "デイリー歩数とストレス" : "日间活动与压力"
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 12, alignment: .leading)], alignment: .leading, spacing: 12) {
                KazeMetricBadge(
                    label: appState.prefs.language == .ja ? "歩数" : "步数",
                    value: dash.stats?.totalSteps.map { "\($0)" } ?? "--",
                    unit: "/ \(dash.stats?.dailyStepGoal ?? 0)"
                )
                KazeMetricBadge(
                    label: appState.prefs.language == .ja ? "消費熱量" : "活跃消耗",
                    value: KazeFormat.integer(dash.stats?.activeCalories),
                    unit: "kcal"
                )
                KazeMetricBadge(
                    label: appState.prefs.language == .ja ? "平均ストレス" : "平均压力",
                    value: dash.stressSummary?.avgStressLevel.map(String.init) ?? "--"
                )
                KazeMetricBadge(
                    label: appState.prefs.language == .ja ? "平均血中酸素" : "平均血氧",
                    value: dash.spo2Data?.avgSpo2Percent.map { String(format: "%.0f%%", $0) } ?? "--"
                )
            }
        }
    }

    private func predictionPill(_ label: String, _ time: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(time ?? "--:--")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(KazeTheme.inkPrimary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KazeTheme.surfaceSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func scheduleRow(_ dash: DashboardSnapshot) -> some View {
        KazeCard {
            KazeSectionHeader(
                jpTag: "PLAN",
                title: appState.prefs.language == .ja ? "練習メニューとクラウドワークアウト" : "近期课表与云端自建课程"
            )
            let coachItems = dash.garminCoachWorkouts?.workouts ?? []
            let cloudWorkouts = dash.workouts?.workouts ?? []

            if coachItems.isEmpty && cloudWorkouts.isEmpty {
                Text(appState.prefs.language == .ja ? "予定されたメニューはありません。「練習メニュー」から作成して時計に送信できます。" : "暂无近期安排课程，可前往「课表与课程」创建并推送至手表。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    if !coachItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(appState.prefs.language == .ja ? "Garmin Coach プラン" : "Garmin Coach 计划")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(coachItems.prefix(4)) { item in
                                HStack {
                                    Text(item.date ?? "")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Text(item.name ?? "训练课")
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(KazeFormat.duration(item.estimatedDurationSeconds.map(Double.init)))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !cloudWorkouts.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(appState.prefs.language == .ja ? "自作ワークアウト (時計送信可)" : "云端自建课程（可直接推表）")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(cloudWorkouts.prefix(4)) { w in
                                HStack {
                                    Text(w.name ?? "未命名课程")
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(KazeFormat.duration(w.estimatedDurationSeconds.map(Double.init)))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Button(appState.prefs.language == .ja ? "送信" : "推表") {
                                        Task { await appState.sendWorkout(id: w.id) }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
