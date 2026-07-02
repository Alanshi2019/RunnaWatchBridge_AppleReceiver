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
    @State private var status: String = "选择 Runna 截图，然后一键接入。v6 会把配速写进 Apple 训练。"
    @State private var isWorking = false
    @State private var easyFast = "5:50"
    @State private var easySlow = "6:30"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("不逃跑计划 Apple v6")
                            .font(.largeTitle.bold())
                        Text("全体起立！")
                            .foregroundStyle(.secondary)
                    }

                    GroupBox("今天怎么说") {
                        VStack(alignment: .leading, spacing: 12) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text(selectedImage == nil ? "选择 Runna 截图" : "重新选择截图")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .onChange(of: selectedItem) { _, newItem in
                                Task { await loadImage(from: newItem) }
                            }

                            if let selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .frame(maxHeight: 260)
                            }
                        }
                    }

                    GroupBox("调整建模") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Easy 快")
                                TextField("5:50", text: $easyFast)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numbersAndPunctuation)
                                Text("慢")
                                TextField("6:30", text: $easySlow)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numbersAndPunctuation)
                            }
                            Text("太慢也可以不填")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Task { await recognizeBuildAndSchedule() }
                    } label: {
                        HStack {
                            if isWorking { ProgressView() }
                            Text(isWorking ? "接入中..." : "创建训练并同步到 Apple Watch")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedImage == nil || isWorking)

                    Text(status)
                        .font(.callout)
                        .foregroundStyle(status.contains("哦吼") ? .red : .secondary)
                        .multilineTextAlignment(.leading)

                    if let workout {
                        GroupBox("训练预览") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(workout.name).bold()
                                ForEach(workout.steps) { step in
                                    if step.type == .repeat {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(step.summary).bold()
                                            ForEach(step.steps ?? []) { child in
                                                Text("  • \(child.summary)")
                                            }
                                        }
                                    } else {
                                        Text(step.summary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !ocrText.isEmpty {
                        DisclosureGroup("识别文本") {
                            TextEditor(text: $ocrText)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 140)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                    ocrText = ""
                    workout = nil
                    status = "截图已就位。"
                }
            }
        } catch {
            await MainActor.run { status = "哦吼，读图失败：\(error.localizedDescription)" }
        }
    }

    private func recognizeBuildAndSchedule() async {
        guard let image = selectedImage else { return }
        await MainActor.run {
            isWorking = true
            status = "识别训练中..."
        }
        defer { Task { @MainActor in isWorking = false } }

        do {
            let text = try await VisionOCR.recognize(image: image)
            let parsed = RunnaTextParser.parse(text: text, easyFast: easyFast, easySlow: easySlow)
            let custom = try WorkoutKitBuilder.build(from: parsed)
            let plan = WorkoutPlan(.custom(custom))
            try await schedule(plan: plan)
            await MainActor.run {
                ocrText = text
                workout = parsed
                status = "接入完成，要活着回来啊。"
            }
        } catch {
            await MainActor.run {
                status = "哦吼，搞坏了：\(error.localizedDescription)"
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
