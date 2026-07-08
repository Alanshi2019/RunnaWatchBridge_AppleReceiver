import SwiftUI
import WorkoutKit
import PhotosUI
import UIKit

struct RunnaBridgeHomeView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var ocrText = ""
    @State private var workout: RunnaWorkout?
    @State private var isWorking = false
    @State private var status = "上传 Runna 截图开始。"
    @State private var easyFast = "5:45"
    @State private var easySlow = "6:30"
    @State private var editingIndex: Int?
    @State private var draftStep = EditableStep()
    @State private var showEditor = false
    @State private var showResultAlert = false
    @State private var resultTitle = ""
    @State private var resultMessage = ""

    private let paceOptions: [String] = stride(from: 180, through: 600, by: 5).map { totalSeconds in
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var stepCount: Int { countSteps(workout?.steps ?? []) }
    private var easyAffectedCount: Int { countEasyAffected(workout?.steps ?? []) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        uploadCard
                        if let workout { stepsCard(workout) }
                        if workout != nil { paceCard }
                        slideAction
                        Label("所有数据仅在本地处理，保护你的隐私", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 36)
                }
            }
            .sheet(isPresented: $showEditor) {
                StepEditorView(draft: $draftStep, easyFast: easyFast, easySlow: easySlow) {
                    saveDraftStep()
                    showEditor = false
                }
                .presentationDetents([.large])
            }
            .alert(resultTitle, isPresented: $showResultAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(resultMessage)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("不逃跑计划")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                GradientSymbol(systemName: "figure.run")
            }
            Text("Runna → Apple Watch")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var uploadCard: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            UploadPickerRow(hasImage: selectedImage != nil, fileName: "runna_screenshot.png", stepCount: stepCount)
        }
        .buttonStyle(.plain)
        .onChange(of: selectedItem) { _, item in
            Task { await loadAndRecognize(item) }
        }
    }

    private func stepsCard(_ workout: RunnaWorkout) -> some View {
        LightCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workout Steps")
                            .font(.title3.bold())
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(stepCount) steps")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.10), in: Capsule())
                }

                ForEach(Array(workout.steps.enumerated()), id: \.element.id) { index, step in
                    StepCard(step: step) {
                        startEditing(step, at: index)
                    } onDelete: {
                        deleteStep(at: index)
                    }
                }

                Button(action: addStep) {
                    Label("Add step", systemImage: "plus")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var paceCard: some View {
        LightCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Easy Pace Zone")
                            .font(.title3.bold())
                        Text("Applied to \(easyAffectedCount) conversation / warmup / cooldown steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Easy")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green, in: Capsule())
                }
                HStack(spacing: 14) {
                    paceWheel("FAST", selection: $easyFast)
                    Text("–").font(.title.bold()).foregroundStyle(.secondary)
                    paceWheel("SLOW", selection: $easySlow)
                }
            }
        }
        .onChange(of: easyFast) { _, _ in applyEasyPaceToWorkout() }
        .onChange(of: easySlow) { _, _ in applyEasyPaceToWorkout() }
    }

    private func paceWheel(_ title: String, selection: Binding<String>) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(paceOptions, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .clipped()
            Text("/ km").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var slideAction: some View {
        SlideToCreateButton(title: "可冲", subtitle: "向右滑动创建并发送到 Apple Watch", disabled: workout == nil || isWorking, isWorking: isWorking) {
            Task { await sendWorkout() }
        }
    }

    private func loadAndRecognize(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            await MainActor.run { isWorking = true; status = "读取截图中..." }
            defer { Task { @MainActor in isWorking = false } }
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
            let text = try await VisionOCR.recognize(image: image)
            let parsed = RunnaTextParser.parse(text: text, easyFast: easyFast, easySlow: easySlow)
            await MainActor.run {
                selectedImage = image
                ocrText = text
                workout = parsed
                applyEasyPaceToWorkout(updateStatus: false)
                status = "✓ \(countSteps(parsed.steps)) steps recognised"
            }
        } catch {
            await MainActor.run { status = "识别失败：\(error.localizedDescription)" }
        }
    }

    private func sendWorkout() async {
        guard let current = workout else { return }
        await MainActor.run { isWorking = true; status = "创建训练中..." }
        defer { Task { @MainActor in isWorking = false } }
        do {
            let plan = WorkoutPlan(.custom(try WorkoutKitBuilder.build(from: current)))
            try await schedule(plan: plan)
            await MainActor.run {
                resetToInitialState()
                resultTitle = "已发送到 Apple Watch"
                resultMessage = "训练已经创建完成，可以在 Apple Watch Workout app 里查看。"
                showResultAlert = true
            }
        } catch {
            await MainActor.run {
                resultTitle = "发送失败"
                resultMessage = error.localizedDescription
                showResultAlert = true
                status = "同步失败：\(error.localizedDescription)"
            }
        }
    }

    private func startEditing(_ step: RunnaStep, at index: Int) {
        editingIndex = index
        draftStep = EditableStep(step: step)
        showEditor = true
    }

    private func saveDraftStep() {
        guard var current = workout, let index = editingIndex, current.steps.indices.contains(index) else { return }
        current.steps[index] = applyEasyPace(to: draftStep.toRunnaStep())
        workout = current
        status = "已更新 step。"
    }

    private func addStep() {
        var current = workout ?? RunnaWorkout(name: "Runna Custom", scheduledDate: nil, steps: [])
        let step = RunnaStep(type: .run, distanceMeters: 400, paceMin: "5:00", paceMax: "5:00", isEasyControlled: false)
        current.steps.append(step)
        workout = current
        startEditing(step, at: current.steps.count - 1)
    }

    private func deleteStep(at index: Int) {
        guard var current = workout, current.steps.indices.contains(index) else { return }
        current.steps.remove(at: index)
        workout = current
        status = "已删除 step。"
    }

    private func applyEasyPaceToWorkout(updateStatus: Bool = true) {
        guard var current = workout else { return }
        current.steps = current.steps.map { applyEasyPace(to: $0) }
        workout = current
        if updateStatus {
            status = "Easy pace 已应用到 \(countEasyAffected(current.steps)) 个 controlled step。"
        }
    }

    private func applyEasyPace(to step: RunnaStep) -> RunnaStep {
        var updated = step
        if isEasyStep(step) {
            updated.paceMin = easyFast
            updated.paceMax = easySlow
        }
        if let children = step.steps {
            updated.steps = children.map { applyEasyPace(to: $0) }
        }
        return updated
    }

    private func isEasyStep(_ step: RunnaStep) -> Bool {
        step.usesEasyPaceZone
    }

    private func resetToInitialState() {
        selectedItem = nil
        selectedImage = nil
        ocrText = ""
        workout = nil
        easyFast = "5:45"
        easySlow = "6:30"
        editingIndex = nil
        draftStep = EditableStep()
        showEditor = false
        status = "上传 Runna 截图开始。"
    }

    private func countEasyAffected(_ steps: [RunnaStep]) -> Int {
        steps.reduce(0) { total, step in
            var count = total + (isEasyStep(step) ? 1 : 0)
            if let children = step.steps { count += countEasyAffected(children) }
            return count
        }
    }

    private func countSteps(_ steps: [RunnaStep]) -> Int {
        steps.reduce(0) { $0 + 1 + ($1.type == .repeat ? countSteps($1.steps ?? []) : 0) }
    }

    @MainActor
    private func schedule(plan: WorkoutPlan) async throws {
        if #available(iOS 17.0, *) {
            guard WorkoutScheduler.isSupported else { throw NSError(domain: "RunnaWatchBridge", code: 1, userInfo: [NSLocalizedDescriptionKey: "这台设备不支持 WorkoutScheduler。请用 iPhone 真机 + 已配对 Apple Watch。"]) }
            let scheduler = WorkoutScheduler.shared
            let auth = await scheduler.requestAuthorization()
            guard auth == .authorized else { throw NSError(domain: "RunnaWatchBridge", code: 2, userInfo: [NSLocalizedDescriptionKey: "WorkoutKit 授权失败：\(String(describing: auth))"]) }
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date().addingTimeInterval(120))
            await scheduler.schedule(plan, at: comps)
        }
    }
}
