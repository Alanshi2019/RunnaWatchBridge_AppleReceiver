import SwiftUI
import WorkoutKit
import PhotosUI
import Vision
import UIKit

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var uploadedFileName = "runna_screenshot.png"
    @State private var ocrText: String = ""
    @State private var workout: RunnaWorkout?
    @State private var status: String = "上传 Runna 截图开始。"
    @State private var isWorking = false
    @State private var easyFast = "5:45"
    @State private var easySlow = "6:30"
    @State private var editingIndex: Int?
    @State private var draftStep = EditableStep()
    @State private var showEditor = false

    private let paceOptions: [String] = [
        "4:30", "4:35", "4:40", "4:45", "4:50", "4:55",
        "5:00", "5:05", "5:10", "5:15", "5:20", "5:25", "5:30", "5:35", "5:40", "5:45", "5:50", "5:55",
        "6:00", "6:05", "6:10", "6:15", "6:20", "6:25", "6:30", "6:35", "6:40", "6:45", "6:50", "6:55",
        "7:00", "7:05", "7:10", "7:15", "7:20", "7:25", "7:30"
    ]

    private var recognizedStepCount: Int {
        countSteps(workout?.steps ?? [])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        uploadCard
                        if workout != nil {
                            recognizedStepsCard
                        }
                        paceCard
                        slideAction
                        privacyFooter
                        ocrDisclosure
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 36)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditor) {
                StepEditorView(draft: $draftStep) {
                    saveDraftStep()
                    showEditor = false
                }
                .presentationDetents([.large])
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("不逃跑计划")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                GradientSymbol(systemName: "figure.run")
                    .frame(width: 34, height: 34)
            }
            Text("Runna → Apple Watch")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    private var uploadCard: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            UploadPickerRow(
                hasImage: selectedImage != nil,
                fileName: uploadedFileName,
                stepCount: recognizedStepCount
            )
        }
        .buttonStyle(.plain)
        .onChange(of: selectedItem) { _, newItem in
            Task { await loadAndRecognizeImage(from: newItem) }
        }
    }

    private var recognizedStepsCard: some View {
        LightCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            Text("Workout Steps")
                                .font(.title3.bold())
                            Text("\(recognizedStepCount) steps")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.purple.opacity(0.10), in: Capsule())
                        }
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        ocrText = workoutToEditableText(workout)
                    } label: {
                        Image(systemName: "text.cursor")
                            .font(.headline)
                            .foregroundStyle(.purple)
                            .frame(width: 38, height: 38)
                            .background(Color.purple.opacity(0.10), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 12) {
                    ForEach(Array((workout?.steps ?? []).enumerated()), id: \.element.id) { index, step in
                        StepCard(step: step) {
                            startEditing(index: index, step: step)
                        } onDelete: {
                            deleteStep(at: index)
                        }
                    }
                }

                Button {
                    addStep()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add step")
                    }
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var paceCard: some View {
        LightCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    HStack(spacing: 10) {
                        GradientSymbol(systemName: "waveform.path.ecg")
                        Text("Easy Pace Zone")
                            .font(.title3.bold())
                    }
                    Spacer()
                    Text("Easy")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green, in: Capsule())
                }

                Text("Applied to \(easyAffectedCount) easy / warmup / cooldown steps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 14) {
                    paceWheel(title: "MIN", selection: $easyFast)
                    Text("–")
                        .font(.title.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 30)
                    paceWheel(title: "MAX", selection: $easySlow)
                }

                EasyPaceRangeBar(options: paceOptions, fast: easyFast, slow: easySlow)
            }
        }
        .onChange(of: easyFast) { _, _ in applyEasyPaceToEasySteps() }
        .onChange(of: easySlow) { _, _ in applyEasyPaceToEasySteps() }
    }

    private var easyAffectedCount: Int {
        countEasyAffected(workout?.steps ?? [])
    }

    private func paceWheel(title: String, selection: Binding<String>) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Picker(title, selection: selection) {
                ForEach(paceOptions, id: \.self) { pace in
                    Text(pace)
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .tag(pace)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .clipped()

            Text("/ km")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var slideAction: some View {
        SlideToCreateButton(
            title: "可冲",
            subtitle: "向右滑动创建并发送到 Apple Watch",
            disabled: isWorking || workout == nil,
            isWorking: isWorking
        ) {
            Task { await createFromCurrentPlan() }
        }
    }

    private var privacyFooter: some View {
        Label("所有数据仅在本地处理，保护你的隐私", systemImage: "lock.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
    }

    @ViewBuilder
    private var ocrDisclosure: some View {
        if !ocrText.isEmpty {
            DisclosureGroup {
                TextEditor(text: $ocrText)
                    .font(.system(.caption, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onChange(of: ocrText) { _, newValue in
                        guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        workout = RunnaTextParser.parse(text: newValue, easyFast: easyFast, easySlow: easySlow)
                    }
            } label: {
                Label("Raw OCR text", systemImage: "text.viewfinder")
                    .font(.headline)
            }
            .padding(16)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color(.systemGray5), lineWidth: 1))
        }
    }

    private func startEditing(index: Int, step: RunnaStep) {
        editingIndex = index
        draftStep = EditableStep(step: step)
        showEditor = true
    }

    private func saveDraftStep() {
        guard var current = workout, let index = editingIndex, current.steps.indices.contains(index) else { return }
        current.steps[index] = draftStep.toRunnaStep()
        workout = current
        ocrText = workoutToEditableText(current)
        status = "已更新 step。"
    }

    private func addStep() {
        var current = workout ?? RunnaWorkout(name: "Runna Custom", scheduledDate: nil, steps: [])
        let step = RunnaStep(type: .run, distanceMeters: 400, durationSeconds: nil, paceMin: easyFast, paceMax: easySlow, iterations: nil, steps: nil)
        current.steps.append(step)
        workout = current
        ocrText = workoutToEditableText(current)
        status = "已添加 1 个 step。"
    }

    private func deleteStep(at index: Int) {
        guard var current = workout, current.steps.indices.contains(index) else { return }
        current.steps.remove(at: index)
        workout = current
        ocrText = workoutToEditableText(current)
        status = "已删除 1 个 step。"
    }

    private func applyEasyPaceToEasySteps() {
        guard var current = workout else { return }
        current.steps = applyEasyPace(current.steps)
        workout = current
    }

    private func applyEasyPace(_ steps: [RunnaStep]) -> [RunnaStep] {
        steps.map { step in
            var updated = step
            if step.type == .warmup || step.type == .cooldown || step.type == .run {
                let hasSpecificPace = step.paceMin != nil && step.paceMin == step.paceMax && step.paceMin != easyFast && step.paceMin != easySlow
                if !hasSpecificPace {
                    updated.paceMin = easyFast
                    updated.paceMax = easySlow
                }
            }
            if let children = step.steps {
                updated.steps = applyEasyPace(children)
            }
            return updated
        }
    }

    private func countEasyAffected(_ steps: [RunnaStep]) -> Int {
        steps.reduce(0) { total, step in
            var count = total
            if step.type == .warmup || step.type == .cooldown || step.type == .run {
                count += 1
            }
            if let children = step.steps {
                count += countEasyAffected(children)
            }
            return count
        }
    }

    private func countSteps(_ steps: [RunnaStep]) -> Int {
        steps.reduce(0) { total, step in
            if step.type == .repeat {
                return total + 1 + countSteps(step.steps ?? [])
            }
            return total + 1
        }
    }

    private func workoutToEditableText(_ workout: RunnaWorkout?) -> String {
        guard let workout else { return "" }
        return workout.steps.map { stepToText($0) }.joined(separator: "\n")
    }

    private func stepToText(_ step: RunnaStep) -> String {
        switch step.type {
        case .repeat:
            let inner = (step.steps ?? []).map { "  " + stepToText($0) }.joined(separator: "\n")
            return "Repeat x\(step.iterations ?? 1)" + (inner.isEmpty ? "" : "\n\(inner)")
        case .warmup:
            return "Warm Up - \(Int(step.distanceMeters ?? 0))m - Easy"
        case .cooldown:
            return "Cool Down - \(Int(step.distanceMeters ?? 0))m - Easy"
        case .recovery, .rest:
            return "Recovery - \(Int(step.durationSeconds ?? 0))s"
        case .run:
            return "Run - \(Int(step.distanceMeters ?? 0))m @ \(step.paceMin ?? easyFast)"
        }
    }

    private func loadAndRecognizeImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            await MainActor.run {
                isWorking = true
                status = "读取截图中..."
            }
            defer { Task { @MainActor in isWorking = false } }

            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw NSError(domain: "RunnaWatchBridge", code: 10, userInfo: [NSLocalizedDescriptionKey: "图片读取失败"])
            }

            let text = try await VisionOCR.recognize(image: image)
            let parsed = RunnaTextParser.parse(text: text, easyFast: easyFast, easySlow: easySlow)
            await MainActor.run {
                selectedImage = image
                uploadedFileName = "runna_screenshot.png"
                ocrText = text
                workout = parsed
                status = "✓ \(countSteps(parsed.steps)) steps recognised"
            }
        } catch {
            await MainActor.run { status = "识别失败：\(error.localizedDescription)" }
        }
    }

    private func createFromCurrentPlan() async {
        guard let current = workout else { return }

        await MainActor.run {
            isWorking = true
            status = "创建训练中..."
        }
        defer { Task { @MainActor in isWorking = false } }

        do {
            let custom = try WorkoutKitBuilder.build(from: current)
            let plan = WorkoutPlan(.custom(custom))
            try await schedule(plan: plan)
            await MainActor.run {
                status = "同步完成。要活着回来啊。"
            }
        } catch {
            await MainActor.run {
                status = "同步失败：\(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func schedule(plan: WorkoutPlan) async throws {
        if #available(iOS 17.0, *) {
            guard WorkoutScheduler.isSupported else {
                throw NSError(domain: "RunnaWatchBridge", code: 1, userInfo: [NSLocalizedDescriptionKey: "这台设备不支持 WorkoutScheduler。请用 iPhone 真机 + 已配对 Apple Watch。"])
            }
            let scheduler = WorkoutScheduler.shared
            let auth = await scheduler.requestAuthorization()
            guard auth == .authorized else {
                throw NSError(domain: "RunnaWatchBridge", code: 2, userInfo: [NSLocalizedDescriptionKey: "WorkoutKit 授权失败：\(String(describing: auth))"])
            }
            var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date().addingTimeInterval(120))
            if comps.hour == nil { comps.hour = 9 }
            if comps.minute == nil { comps.minute = 0 }
            await scheduler.schedule(plan, at: comps)
        } else {
            throw NSError(domain: "RunnaWatchBridge", code: 3, userInfo: [NSLocalizedDescriptionKey: "Requires iOS 17+"])
        }
    }
}

private struct UploadPickerRow: View {
    let hasImage: Bool
    let fileName: String
    let stepCount: Int

    var body: some View {
        HStack(spacing: 16) {
            icon
            textBlock
            Spacer()
            actionLabel
        }
        .padding(18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(.systemGray6), lineWidth: 1))
        .shadow(color: .black.opacity(0.055), radius: 18, x: 0, y: 10)
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(hasImage ? Color.blue.opacity(0.10) : Color.purple.opacity(0.11))
            Image(systemName: hasImage ? "checkmark.circle.fill" : "photo.on.rectangle.angled")
                .font(.title2.weight(.semibold))
                .foregroundStyle(hasImage ? .green : .purple)
        }
        .frame(width: 58, height: 58)
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(hasImage ? fileName : "上传 Runna 截图")
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(hasImage ? "✓ \(stepCount) steps recognised" : "支持长截图")
                .font(.subheadline.weight(hasImage ? .semibold : .regular))
                .foregroundStyle(hasImage ? .green : .secondary)
        }
    }

    private var actionLabel: some View {
        Text(hasImage ? "Replace" : "选择")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(hasImage ? .primary : .purple)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }
}

private struct EditableStep {
    var type: RunnaStepType = .run
    var distanceMeters: String = "400"
    var durationSeconds: String = "90"
    var paceMin: String = "5:45"
    var paceMax: String = "6:30"
    var iterations: String = "1"

    init() {}

    init(step: RunnaStep) {
        type = step.type
        distanceMeters = step.distanceMeters.map { String(Int($0)) } ?? ""
        durationSeconds = step.durationSeconds.map { String(Int($0)) } ?? ""
        paceMin = step.paceMin ?? ""
        paceMax = step.paceMax ?? ""
        iterations = step.iterations.map(String.init) ?? "1"
    }

    func toRunnaStep() -> RunnaStep {
        RunnaStep(
            type: type,
            distanceMeters: Double(distanceMeters),
            durationSeconds: Double(durationSeconds),
            paceMin: paceMin.isEmpty ? nil : paceMin,
            paceMax: paceMax.isEmpty ? nil : paceMax,
            iterations: Int(iterations),
            steps: type == .repeat ? [RunnaStep(type: .run, distanceMeters: Double(distanceMeters) ?? 400, durationSeconds: nil, paceMin: paceMin.isEmpty ? nil : paceMin, paceMax: paceMax.isEmpty ? nil : paceMax, iterations: nil, steps: nil)] : nil
        )
    }
}

private struct StepEditorView: View {
    @Binding var draft: EditableStep
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Step type") {
                    Picker("Type", selection: $draft.type) {
                        Text("Warm-up").tag(RunnaStepType.warmup)
                        Text("Run").tag(RunnaStepType.run)
                        Text("Recovery").tag(RunnaStepType.recovery)
                        Text("Cool-down").tag(RunnaStepType.cooldown)
                        Text("Repeat").tag(RunnaStepType.repeat)
                    }
                }

                Section("Fields") {
                    if draft.type == .repeat {
                        TextField("Iterations", text: $draft.iterations)
                            .keyboardType(.numberPad)
                    }
                    if draft.type != .recovery && draft.type != .rest {
                        TextField("Distance meters", text: $draft.distanceMeters)
                            .keyboardType(.decimalPad)
                    }
                    if draft.type == .recovery || draft.type == .rest {
                        TextField("Duration seconds", text: $draft.durationSeconds)
                            .keyboardType(.decimalPad)
                    }
                    TextField("Pace min", text: $draft.paceMin)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Pace max", text: $draft.paceMax)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .navigationTitle("Edit Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
    }
}

private struct StepCard: View {
    let step: RunnaStep
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var accent: Color {
        switch step.type {
        case .warmup: return .orange
        case .cooldown: return .red
        case .recovery, .rest: return .cyan
        case .repeat: return .purple
        case .run: return .green
        }
    }

    private var typeTitle: String {
        switch step.type {
        case .warmup: return "Warm-up"
        case .cooldown: return "Cool-down"
        case .recovery, .rest: return "Recovery"
        case .repeat: return "Interval"
        case .run: return "Easy"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(typeTitle.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.12), in: Capsule())
                    if step.type == .repeat, let iterations = step.iterations {
                        Text("×\(iterations)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                    }
                    Spacer()
                }

                Text(step.summary)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if step.type == .repeat, let children = step.steps, !children.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(children.prefix(3)) { child in
                            Text(child.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 6)

            HStack(spacing: 10) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 38, height: 38)
                        .background(Color(.secondarySystemGroupedBackground), in: Circle())
                }
                .buttonStyle(.plain)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(width: 38, height: 38)
                        .background(Color.red.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct EasyPaceRangeBar: View {
    let options: [String]
    let fast: String
    let slow: String

    private var start: CGFloat {
        guard let idx = options.firstIndex(of: fast), options.count > 1 else { return 0 }
        return CGFloat(idx) / CGFloat(options.count - 1)
    }

    private var end: CGFloat {
        guard let idx = options.firstIndex(of: slow), options.count > 1 else { return 1 }
        return CGFloat(idx) / CGFloat(options.count - 1)
    }

    var body: some View {
        GeometryReader { geo in
            let left = min(start, end) * geo.size.width
            let right = max(start, end) * geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5)).frame(height: 8)
                Capsule().fill(Color.green).frame(width: max(10, right - left), height: 8).offset(x: left)
                Circle().fill(.white).overlay(Circle().stroke(Color.green, lineWidth: 3)).frame(width: 18, height: 18).offset(x: max(0, left - 9))
                Circle().fill(.white).overlay(Circle().stroke(Color.green, lineWidth: 3)).frame(width: 18, height: 18).offset(x: min(geo.size.width - 18, right - 9))
            }
        }
        .frame(height: 22)
        .overlay(alignment: .bottomLeading) { Text("faster").font(.caption2).foregroundStyle(.secondary).offset(y: 14) }
        .overlay(alignment: .bottomTrailing) { Text("slower").font(.caption2).foregroundStyle(.secondary).offset(y: 14) }
        .padding(.bottom, 12)
    }
}

private struct LightCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(.systemGray6), lineWidth: 1))
            .shadow(color: .black.opacity(0.055), radius: 20, x: 0, y: 10)
    }
}

private struct GradientSymbol: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.title2.weight(.bold))
            .foregroundStyle(
                LinearGradient(colors: [.mint, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
    }
}

private struct SlideToCreateButton: View {
    let title: String
    let subtitle: String
    let disabled: Bool
    let isWorking: Bool
    let action: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var didTrigger = false

    var body: some View {
        GeometryReader { geo in
            let knobSize: CGFloat = 68
            let maxOffset = max(0, geo.size.width - knobSize - 10)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: disabled ? [Color(.systemGray3), Color(.systemGray2)] : [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: disabled ? .clear : .purple.opacity(0.25), radius: 18, x: 0, y: 10)

                HStack(spacing: 12) {
                    Spacer().frame(width: knobSize + 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.title2.bold())
                        Text(subtitle)
                            .font(.caption.weight(.medium))
                            .opacity(0.82)
                    }
                    Spacer()
                    Image(systemName: "chevron.right.2")
                        .font(.headline.bold())
                        .opacity(0.45)
                        .padding(.trailing, 22)
                }
                .foregroundStyle(.white)

                Circle()
                    .fill(.white)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Group {
                            if isWorking {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.right")
                                    .font(.title2.bold())
                                    .foregroundStyle(disabled ? Color(.systemGray2) : .purple)
                            }
                        }
                    )
                    .padding(.leading, 5)
                    .offset(x: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !disabled, !isWorking else { return }
                                dragOffset = min(max(0, value.translation.width), maxOffset)
                            }
                            .onEnded { _ in
                                guard !disabled, !isWorking else { return }
                                if dragOffset > maxOffset * 0.72, !didTrigger {
                                    didTrigger = true
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        dragOffset = maxOffset
                                    }
                                    action()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            dragOffset = 0
                                            didTrigger = false
                                        }
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: 78)
        .opacity(disabled ? 0.72 : 1)
    }
}

enum VisionOCR {
    static func recognize(image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "VisionOCR", code: 1, userInfo: [NSLocalizedDescriptionKey: "图片格式不支持"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum RunnaTextParser {
    static func parse(text rawText: String, easyFast: String, easySlow: String) -> RunnaWorkout {
        var text = rawText.replacingOccurrences(of: "\r", with: "\n")
        if let range = text.range(of: "Details", options: [.caseInsensitive]) {
            text = String(text[range.lowerBound...])
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        let name = "Runna \(formatter.string(from: Date()))"

        var steps: [RunnaStep] = []
        var section: String = ""
        var repeatIterations: Int?
        var repeatSteps: [RunnaStep] = []
        var pendingEasyPace: (String, String)? = nil

        func flushRepeat() {
            if let n = repeatIterations, !repeatSteps.isEmpty {
                steps.append(RunnaStep(type: .repeat, iterations: n, steps: repeatSteps))
            }
            repeatIterations = nil
            repeatSteps = []
        }

        func append(_ step: RunnaStep) {
            if repeatIterations != nil && section != "cooldown" {
                repeatSteps.append(step)
            } else {
                steps.append(step)
            }
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { normalize($0) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for line in lines {
            let lower = line.lowercased()
            if shouldIgnore(lower) { continue }

            if lower.contains("warmup") || lower.contains("warm up") {
                section = "warmup"
                continue
            }
            if lower.contains("cooldown") || lower.contains("cool down") {
                flushRepeat()
                section = "cooldown"
                continue
            }
            if lower.contains("repeat") {
                if let n = firstInt(in: lower) {
                    flushRepeat()
                    section = "set"
                    repeatIterations = n
                    continue
                }
            }
            if lower == "set" || lower.contains(" set ") || lower.hasSuffix(" set") {
                section = "set"
                continue
            }

            if let pace = paceString(in: lower), lower.contains("no faster") {
                pendingEasyPace = (pace, easySlow.isEmpty ? pace : easySlow)
                continue
            }

            if let rest = restSeconds(in: lower) {
                append(RunnaStep(type: .recovery, durationSeconds: Double(rest)))
                continue
            }

            if let meters = distanceMeters(in: lower) {
                let pace = paceString(in: lower)
                var stepType: RunnaStepType = .run
                if section == "warmup" { stepType = .warmup }
                if section == "cooldown" { stepType = .cooldown }

                let pMin: String?
                let pMax: String?
                if let pace {
                    pMin = pace
                    pMax = pace
                } else if lower.contains("conversation") || lower.contains("conversational") || lower.contains("easy") || section == "warmup" || section == "cooldown" {
                    pMin = pendingEasyPace?.0 ?? (easyFast.isEmpty ? nil : easyFast)
                    pMax = pendingEasyPace?.1 ?? (easySlow.isEmpty ? nil : easySlow)
                } else {
                    pMin = nil
                    pMax = nil
                }
                append(RunnaStep(type: stepType, distanceMeters: meters, paceMin: pMin, paceMax: pMax))
                if section == "warmup" { section = "set" }
            }
        }
        flushRepeat()

        if steps.isEmpty {
            steps = placeholderSteps(easyFast: easyFast, easySlow: easySlow)
        }
        return RunnaWorkout(name: name, scheduledDate: nil, steps: steps)
    }

    private static func normalize(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "|", with: " ")
        s = s.replacingOccurrences(of: "~~»,", with: " ")
        s = s.replacingOccurrences(of: "~~»,", with: " ")
        s = s.replacingOccurrences(of: "kmat", with: "km at", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "mat", with: "m at", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "8oom", with: "800m", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "6oom", with: "600m", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "4oom", with: "400m", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "2oom", with: "200m", options: .caseInsensitive)
        return s
    }

    private static func shouldIgnore(_ lower: String) -> Bool {
        let bad = ["stretches", "start workout", "athlete", "olympian", "we're", "playing", "chatgpt", "wechat", "outdoor", "treadmill"]
        return bad.contains { lower.contains($0) }
    }

    private static func firstInt(in s: String) -> Int? {
        let pattern = #"\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let range = Range(match.range, in: s) else { return nil }
        return Int(s[range])
    }

    private static func paceString(in s: String) -> String? {
        let pattern = #"\b\d{1,2}:[0-5]\d\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let range = Range(match.range, in: s) else { return nil }
        return String(s[range])
    }

    private static func restSeconds(in s: String) -> Int? {
        let pattern = #"(\d+)\s*s(?:ec|econds)?\b.*(rest|walk|walking|recovery)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let range = Range(match.range(at: 1), in: s) else { return nil }
        return Int(s[range])
    }

    private static func distanceMeters(in s: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)\s*(km|k|m)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let valueRange = Range(match.range(at: 1), in: s),
              let unitRange = Range(match.range(at: 2), in: s),
              let value = Double(s[valueRange]) else { return nil }
        let unit = s[unitRange].lowercased()
        return unit == "m" ? value : value * 1000
    }

    private static func placeholderSteps(easyFast: String, easySlow: String) -> [RunnaStep] {
        [
            RunnaStep(type: .warmup, distanceMeters: 2000, paceMin: easyFast, paceMax: easySlow),
            RunnaStep(type: .repeat, iterations: 4, steps: [
                RunnaStep(type: .run, distanceMeters: 400, paceMin: "5:00", paceMax: "5:00"),
                RunnaStep(type: .run, distanceMeters: 400, paceMin: "5:40", paceMax: "5:40"),
                RunnaStep(type: .recovery, durationSeconds: 90)
            ]),
            RunnaStep(type: .cooldown, distanceMeters: 1200, paceMin: easyFast, paceMax: easySlow)
        ]
    }
}

#Preview {
    ContentView()
}
