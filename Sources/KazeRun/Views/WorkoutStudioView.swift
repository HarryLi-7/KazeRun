import SwiftUI

struct WorkoutStudioView: View {
    @Environment(AppState.self) private var appState

    @State private var editingWorkoutId: Int? = nil
    @State private var workoutName: String = "AI 节奏间歇课"
    @State private var workoutDesc: String = "KazeRun 原生构建"
    @State private var steps: [EditableWorkoutStep] = [
        EditableWorkoutStep(kind: "warmup", endType: "time", seconds: 600, targetType: "hr", hrLow: 120, hrHigh: 145),
        EditableWorkoutStep(
            kind: "repeat",
            iterations: 3,
            steps: [
                EditableWorkoutStep(kind: "interval", endType: "time", seconds: 600, targetType: "pace", paceFastSec: 255, paceSlowSec: 265),
                EditableWorkoutStep(kind: "recovery", endType: "time", seconds: 120, targetType: "none")
            ]
        ),
        EditableWorkoutStep(kind: "cooldown", endType: "time", seconds: 480, targetType: "none")
    ]
    @State private var includeScheduleDate: Bool = false
    @State private var scheduleDate: Date = Date()
    @State private var sendAfterSave: Bool = true
    @State private var isSaving: Bool = false
    @State private var isLoadingInspect: Bool = false
    @State private var studioFeedback: String?

    var body: some View {
        HSplitView {
            leftScheduleAndLibraryPane
                .frame(minWidth: 320, idealWidth: 380, maxWidth: 440)

            rightBuilderPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(KazeTheme.canvas)
    }

    private var leftScheduleAndLibraryPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WORKOUTS & CALENDAR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(KazeTheme.vermilion)
                        Text("云端课表与日程")
                            .font(.system(size: 18, weight: .bold))
                    }
                    Spacer()
                    Button("新建课程") {
                        resetToNewTemplate()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(KazeTheme.vermilion)
                    .controlSize(.small)
                }

                // Cloud Custom Workouts
                KazeCard(padding: 12) {
                    KazeSectionHeader(
                        jpTag: "CLOUD",
                        title: "云端自建课程",
                        subtitle: "\(appState.dashboard?.workouts?.workouts?.count ?? 0) 节"
                    )
                    let list = appState.dashboard?.workouts?.workouts ?? []
                    if list.isEmpty {
                        Text("暂无云端自定义课程").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(list) { w in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(w.name ?? "未命名")
                                        .font(.system(size: 13, weight: .semibold))
                                    Spacer()
                                    Text(KazeFormat.duration(w.estimatedDurationSeconds.map(Double.init)))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                if let desc = w.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                HStack(spacing: 6) {
                                    Button("编辑") {
                                        Task { await loadWorkoutIntoEditor(id: w.id) }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)

                                    Button("推表") {
                                        Task { await appState.sendWorkout(id: w.id) }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)

                                    Button("排期今日") {
                                        Task { await appState.scheduleWorkout(id: w.id, date: AppState.isoDateString(Date())) }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)

                                    Spacer()

                                    Button("删除", role: .destructive) {
                                        Task { await appState.deleteWorkout(id: w.id) }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                            }
                            .padding(8)
                            .background(editingWorkoutId == w.id ? KazeTheme.vermilion.opacity(0.08) : KazeTheme.surfaceSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Garmin Coach
                KazeCard(padding: 12) {
                    KazeSectionHeader(jpTag: "COACH", title: "Garmin Coach 自适应课表")
                    let coachList = appState.dashboard?.garminCoachWorkouts?.workouts ?? []
                    if coachList.isEmpty {
                        Text("暂无 Coach 课程").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(coachList) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "训练")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("\(item.date ?? "") · \(item.workoutType ?? "")")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.completed == true ? "已完成" : KazeFormat.duration(item.estimatedDurationSeconds.map(Double.init)))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(item.completed == true ? KazeTheme.sage : .secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                // Scheduled & Calendar Events
                KazeCard(padding: 12) {
                    KazeSectionHeader(jpTag: "CAL", title: "近期排期与赛事")
                    let scheduled = appState.dashboard?.scheduledWorkouts?.allItems ?? []
                    let events = appState.dashboard?.calendarEvents?.events ?? []
                    if scheduled.isEmpty && events.isEmpty {
                        Text("未来 30 天暂无排期或赛事").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(events) { ev in
                            HStack {
                                Text(ev.date ?? "").font(.system(size: 11, design: .monospaced)).foregroundStyle(KazeTheme.vermilion)
                                Text(ev.title ?? "赛事").font(.system(size: 12, weight: .semibold))
                                Spacer()
                            }
                        }
                        ForEach(scheduled) { sw in
                            HStack {
                                Text(sw.date ?? "").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                                Text(sw.workoutName ?? sw.name ?? "已排课程").font(.system(size: 12))
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var rightBuilderPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                KazeCard {
                    HStack {
                        KazeSectionHeader(
                            jpTag: "STUDIO",
                            title: editingWorkoutId == nil ? "新建跑步训练课" : "编辑课程 #\(editingWorkoutId!)"
                        )
                        if isLoadingInspect {
                            ProgressView().controlSize(.small)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        TextField("课程名称", text: $workoutName)
                            .textFieldStyle(.roundedBorder)
                        TextField("课程说明（会同步到 Garmin 备注）", text: $workoutDesc)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                KazeCard {
                    HStack {
                        KazeSectionHeader(jpTag: "STEPS", title: "训练步骤编排", subtitle: "\(steps.count) 个顶层块")
                        Button("+ 添加单步") {
                            steps.append(EditableWorkoutStep(kind: "interval", endType: "time", seconds: 300))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("+ 添加循环组") {
                            steps.append(
                                EditableWorkoutStep(
                                    kind: "repeat",
                                    iterations: 4,
                                    steps: [
                                        EditableWorkoutStep(kind: "interval", endType: "distance", meters: 1000, targetType: "pace", paceFastSec: 250, paceSlowSec: 260),
                                        EditableWorkoutStep(kind: "recovery", endType: "time", seconds: 90)
                                    ]
                                )
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    VStack(spacing: 10) {
                        ForEach($steps) { $step in
                            if step.kind == "repeat" {
                                repeatGroupEditor(step: $step) {
                                    steps.removeAll { $0.id == step.id }
                                }
                            } else {
                                leafStepEditor(step: $step) {
                                    steps.removeAll { $0.id == step.id }
                                }
                            }
                        }
                    }
                }

                KazeCard {
                    HStack(spacing: 16) {
                        if editingWorkoutId == nil {
                            Toggle("同步排期到日历", isOn: $includeScheduleDate)
                            if includeScheduleDate {
                                DatePicker("", selection: $scheduleDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }
                        Toggle("保存后立即推送至手表队列", isOn: $sendAfterSave)
                        Spacer()
                        if let studioFeedback {
                            Text(studioFeedback)
                                .font(.system(size: 12))
                                .foregroundStyle(KazeTheme.vermilion)
                        }
                        Button {
                            Task { await saveWorkout() }
                        } label: {
                            if isSaving {
                                ProgressView().controlSize(.small)
                            } else {
                                Text(editingWorkoutId == nil ? "创建并保存课程" : "更新保存课程")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(KazeTheme.vermilion)
                        .disabled(isSaving || workoutName.trimmingCharacters(in: .whitespaces).isEmpty || steps.isEmpty)
                    }
                }
            }
            .padding(18)
        }
    }

    private func repeatGroupEditor(step: Binding<EditableWorkoutStep>, onDelete: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("REPEAT 循环组")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(KazeTheme.vermilion)
                Stepper("次数：\(step.wrappedValue.iterations) 组", value: step.iterations, in: 1...50)
                    .font(.system(size: 12))
                Spacer()
                Button("+ 组内步骤") {
                    step.wrappedValue.steps.append(EditableWorkoutStep(kind: "interval", endType: "time", seconds: 180))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button("删除组", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }

            VStack(spacing: 6) {
                ForEach(step.steps) { $child in
                    leafStepEditor(step: $child) {
                        step.wrappedValue.steps.removeAll { $0.id == child.id }
                    }
                }
            }
            .padding(.leading, 14)
        }
        .padding(10)
        .background(KazeTheme.vermilion.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(KazeTheme.vermilion.opacity(0.25), lineWidth: 1)
        )
    }

    private func leafStepEditor(step: Binding<EditableWorkoutStep>, onDelete: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Picker("", selection: step.kind) {
                    Text("热身").tag("warmup")
                    Text("间歇/主课").tag("interval")
                    Text("恢复").tag("recovery")
                    Text("休息").tag("rest")
                    Text("冷身").tag("cooldown")
                }
                .labelsHidden()
                .frame(width: 110)

                Picker("", selection: step.endType) {
                    Text("按时间").tag("time")
                    Text("按距离").tag("distance")
                    Text("按圈键").tag("lap_button")
                }
                .labelsHidden()
                .frame(width: 96)

                if step.wrappedValue.endType == "time" {
                    TextField("秒", value: step.seconds, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 68)
                    Text("秒 (\(KazeFormat.duration(Double(step.wrappedValue.seconds))))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else if step.wrappedValue.endType == "distance" {
                    TextField("米", value: step.meters, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 78)
                    Text("米")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Picker("", selection: step.targetType) {
                    Text("无目标").tag("none")
                    Text("配速区间").tag("pace")
                    Text("心率区间").tag("hr")
                }
                .labelsHidden()
                .frame(width: 100)

                if step.wrappedValue.targetType == "pace" {
                    Text("快(s/km)").font(.system(size: 10)).foregroundStyle(.secondary)
                    TextField("255", value: step.paceFastSec, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                    Text("慢(s/km)").font(.system(size: 10)).foregroundStyle(.secondary)
                    TextField("265", value: step.paceSlowSec, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                    Text("\(appState.prefs.formatPace(secondsPerKm: Double(step.wrappedValue.paceFastSec)))–\(appState.prefs.formatPace(secondsPerKm: Double(step.wrappedValue.paceSlowSec)))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(KazeTheme.indigo)
                } else if step.wrappedValue.targetType == "hr" {
                    TextField("低bpm", value: step.hrLow, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                    Text("–")
                    TextField("高bpm", value: step.hrHigh, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                    Text("bpm").font(.system(size: 11)).foregroundStyle(.secondary)
                }

                Spacer()
                Button("删", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .padding(8)
        .background(KazeTheme.surfaceSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func resetToNewTemplate() {
        editingWorkoutId = nil
        workoutName = "新跑步课程"
        workoutDesc = ""
        studioFeedback = nil
    }

    private func loadWorkoutIntoEditor(id: Int) async {
        isLoadingInspect = true
        studioFeedback = nil
        defer { isLoadingInspect = false }
        do {
            let info = try await appState.inspectWorkout(id: id)
            editingWorkoutId = id
            workoutName = info.name ?? "课程 #\(id)"
            workoutDesc = info.description ?? ""
            steps = info.steps.isEmpty ? [EditableWorkoutStep(kind: "interval", endType: "time", seconds: 600)] : info.steps
        } catch {
            studioFeedback = "读取课程失败：\(error.localizedDescription)"
        }
    }

    private func saveWorkout() async {
        isSaving = true
        studioFeedback = nil
        defer { isSaving = false }
        do {
            if let id = editingWorkoutId {
                try await appState.updateWorkout(
                    id: id,
                    name: workoutName,
                    description: workoutDesc,
                    steps: steps,
                    send: sendAfterSave
                )
            } else {
                let sched = includeScheduleDate ? AppState.isoDateString(scheduleDate) : nil
                let newId = try await appState.createWorkout(
                    name: workoutName,
                    description: workoutDesc,
                    steps: steps,
                    scheduleDate: sched,
                    send: sendAfterSave
                )
                editingWorkoutId = newId > 0 ? newId : nil
            }
        } catch {
            studioFeedback = "保存失败：\(error.localizedDescription)"
        }
    }
}
