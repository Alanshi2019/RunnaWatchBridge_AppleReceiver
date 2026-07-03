import SwiftUI
import WorkoutKit
import PhotosUI
import Vision
import UIKit

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var ocrText: String = ""
    @State private var workout: RunnaWorkout?
    @State private var status: String = "上传 Runna 截图开始。"
    @State private var isWorking = false
    @State private var easyFast = "5:45"
    @State private var easySlow = "6:30"

    private let paceOptions: [String] = [
        "4:30", "4:35", "4:40", "4:45", "4:50", "4:55",
        "5:00", "5:05", "5:10", "5:15", "5:20", "5:25", "5:30", "5:35", "5:40", "5:45", "5:50", "5:55",
        "6:00", "6:05", "6:10", "6:15", "6:20", "6:25", "6:30", "6:35", "6:40", "6:45", "6:50", "6:55",
        "7:00", "7:05", "7:10", "7:15", "7:20", "7:25", "7:30"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        uploadCard
                        recognizedEditor
                        paceCard
                        slideAction
                        privacyFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 36)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.purple.opacity(0.11))
                    Image(systemName: selectedImage == nil ? "photo.on.rectangle.angled" : "checkmark.circle.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(selectedImage == nil ? .purple : .green)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedImage == nil ? "上传 Runna 截图" : "截图已上传")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(selectedImage == nil ? "支持长截图" : "重新上传或直接编辑识别内容")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(18)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(.systemGray6), lineWidth: 1))
            .shadow(color: .black.opacity(0.055), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .onChange(of: selectedItem) { _, newItem in
            Task { await loadAndRecognizeImage(from: newItem) }
        }
    }

    private var recognizedEditor: some View {
        LightCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 10) {
                        Text(ocrText.isEmpty ? "训练内容" : "已识别训练计划")
                            .font(.title3.bold())
                        if !ocrText.isEmpty {
                            Text("可编辑")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.purple.opacity(0.10), in: Capsule())
                        }
                    }
                    Spacer()
                    if !ocrText.isEmpty {
                        Button("清空") {
                            ocrText = ""
                            workout = nil
                            status = "已清空识别内容。"
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.purple)
                    }
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $ocrText)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.primary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 210)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.systemGray5), lineWidth: 1))
                        .onChange(of: ocrText) { _, newValue in
                            guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            workout = RunnaTextParser.parse(text: newValue, easyFast: easyFast, easySlow: easySlow)
                        }

                    if ocrText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("上传截图后，识别出的训练文字会出现在这里。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text("识别有误可以直接改，滑动按钮时会按这里的内容创建训练。")
                                .font(.caption)
                                .foregroundStyle(Color(.systemGray2))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                    Text(ocrText.isEmpty ? status : "识别有误？直接修改上方内容。")
                    Spacer()
                    if !ocrText.isEmpty {
                        Text("\(ocrText.count)/5000")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var paceCard: some View {
        LightCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    HStack(spacing: 10) {
                        GradientSymbol(systemName: "waveform.path.ecg")
                        Text("Easy Pace 配速范围")
                            .font(.title3.bold())
                    }
                    Spacer()
                    Text("推荐 5:30 – 6:30 /km")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.purple)
                }

                HStack(alignment: .center, spacing: 14) {
                    paceWheel(title: "最快配速", selection: $easyFast)
                    Text("–")
                        .font(.title.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 30)
                    paceWheel(title: "最慢配速", selection: $easySlow)
                }
            }
        }
    }

    private func paceWheel(title: String, selection: Binding<String>) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
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
            .frame(height: 140)
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
            disabled: isWorking || ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            isWorking: isWorking
        ) {
            Task { await createFromEditedText() }
        }
    }

    private var privacyFooter: some View {
        Label("所有数据仅在本地处理，保护你的隐私", systemImage: "lock.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
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
                ocrText = text
                workout = parsed
                status = "截图已识别。"
            }
        } catch {
            await MainActor.run { status = "识别失败：\(error.localizedDescription)" }
        }
    }

    private func createFromEditedText() async {
        let text = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        await MainActor.run {
            isWorking = true
            status = "创建训练中..."
        }
        defer { Task { @MainActor in isWorking = false } }

        do {
            let parsed = RunnaTextParser.parse(text: text, easyFast: easyFast, easySlow: easySlow)
            let custom = try WorkoutKitBuilder.build(from: parsed)
            let plan = WorkoutPlan(.custom(custom))
            try await schedule(plan: plan)
            await MainActor.run {
                workout = parsed
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
