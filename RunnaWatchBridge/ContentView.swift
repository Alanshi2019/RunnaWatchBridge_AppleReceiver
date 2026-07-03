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
    @State private var status: String = "尚未识别训练计划"
    @State private var isWorking = false
    @State private var easyFast = "5:45"
    @State private var easySlow = "6:30"

    private let paceOptions: [String] = [
        "4:30", "4:35", "4:40", "4:45", "4:50", "4:55",
        "5:00", "5:05", "5:10", "5:15", "5:20", "5:25", "5:30", "5:35", "5:40", "5:45", "5:50", "5:55",
        "6:00", "6:05", "6:10", "6:15", "6:20", "6:25", "6:30", "6:35", "6:40", "6:45", "6:50", "6:55",
        "7:00", "7:05", "7:10", "7:15", "7:20", "7:25", "7:30"
    ]

    private var watchReady: Bool {
        if #available(iOS 17.0, *) {
            return WorkoutScheduler.isSupported
        }
        return false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        uploadCard
                        paceCard
                        deviceCard
                        actionButton
                        privacyFooter
                        previewCard
                        ocrDisclosure
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
            Text("不逃跑计划")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("Runna → Apple Watch")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 10)
    }

    private var uploadCard: some View {
        LightCard {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("上传 Runna 截图")
                        .font(.title2.bold())
                    Text("上传后会自动识别并创建训练")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    VStack(spacing: 14) {
                        UploadIcon()
                            .frame(width: 78, height: 78)
                        Text(selectedImage == nil ? "上传图片" : "重新上传")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        Text("支持长截图")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 245)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 1.4, dash: [7, 7]))
                    )
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .onChange(of: selectedItem) { _, newItem in
                    Task { await loadImage(from: newItem) }
                }

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .frame(maxHeight: 240)
                        .frame(maxWidth: .infinity)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.systemGray5), lineWidth: 1))
                }
            }
        }
    }

    private var paceCard: some View {
        LightCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    HStack(spacing: 10) {
                        GradientSymbol(systemName: "figure.run")
                        Text("配速设置")
                            .font(.title3.bold())
                    }
                    Spacer()
                    Text("Easy Pace")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.blue.opacity(0.10), in: Capsule())
                }

                HStack(alignment: .center, spacing: 14) {
                    paceWheel(title: "最快配速", selection: $easyFast)
                    Text("–")
                        .font(.title.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 32)
                    paceWheel(title: "最慢配速", selection: $easySlow)
                }

                Text("设置 easy 配速范围，App 会根据这个范围生成训练计划。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
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
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .tag(pace)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipped()

            Text("/ km")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var deviceCard: some View {
        LightCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("设备状态")
                    .font(.title3.bold())

                VStack(spacing: 0) {
                    deviceRow(
                        icon: "applewatch",
                        iconColor: .blue,
                        title: "Apple Watch",
                        status: watchReady ? "已就绪" : "未检测到",
                        statusColor: watchReady ? .green : .orange,
                        trailing: watchReady ? "checkmark" : "exclamationmark"
                    )

                    Divider()
                        .padding(.leading, 72)

                    deviceRow(
                        icon: "heart.fill",
                        iconColor: .red,
                        title: "WorkoutKit",
                        status: isWorking || workout != nil ? "已授权" : "待授权",
                        statusColor: isWorking || workout != nil ? .green : .orange,
                        trailing: "chevron.right"
                    )
                }
            }
        }
    }

    private func deviceRow(icon: String, iconColor: Color, title: String, status: String, statusColor: Color, trailing: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.weight(.medium))
                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(status)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(statusColor)
                }
            }

            Spacer()

            Image(systemName: trailing)
                .font(.headline.weight(.semibold))
                .foregroundStyle(trailing == "checkmark" ? .green : Color(.systemGray3))
                .frame(width: 36, height: 36)
                .background(trailing == "checkmark" ? Color.green.opacity(0.12) : .clear, in: Circle())
        }
        .padding(.vertical, 12)
    }

    private var actionButton: some View {
        Button {
            Task { await recognizeBuildAndSchedule() }
        } label: {
            HStack(spacing: 14) {
                if isWorking {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.title3.bold())
                }
                Text(isWorking ? "创建中..." : "创建并发送到 Apple Watch")
                    .font(.headline.bold())
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.headline.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: selectedImage == nil || isWorking ? [Color(.systemGray3), Color(.systemGray2)] : [.black, Color(red: 0.10, green: 0.13, blue: 0.17)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .shadow(color: .black.opacity(selectedImage == nil ? 0.08 : 0.22), radius: 18, x: 0, y: 10)
        }
        .disabled(selectedImage == nil || isWorking)
        .buttonStyle(.plain)
    }

    private var privacyFooter: some View {
        Label("所有数据在本地处理，保护你的隐私", systemImage: "lock.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
    }

    @ViewBuilder
    private var previewCard: some View {
        if let workout {
            LightCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("训练预览")
                        .font(.title3.bold())
                    Text(workout.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(workout.steps) { step in
                            if step.type == .repeat {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(step.summary)
                                        .font(.headline)
                                    ForEach(step.steps ?? []) { child in
                                        Text(child.summary)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .padding(.leading, 14)
                                    }
                                }
                            } else {
                                Text(step.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var ocrDisclosure: some View {
        if !ocrText.isEmpty {
            DisclosureGroup {
                TextEditor(text: $ocrText)
                    .font(.system(.caption, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } label: {
                Label("识别文本", systemImage: "text.viewfinder")
                    .font(.headline)
            }
            .padding(16)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color(.systemGray5), lineWidth: 1))
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
            await MainActor.run { status = "同步失败：读图失败：\(error.localizedDescription)" }
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
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(.systemGray6), lineWidth: 1))
            .shadow(color: .black.opacity(0.055), radius: 20, x: 0, y: 10)
    }
}

private struct UploadIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [.blue.opacity(0.75), .cyan.opacity(0.55), .purple.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .blur(radius: 0.2)
            Image(systemName: "icloud.and.arrow.up.fill")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: .blue.opacity(0.28), radius: 14, x: 0, y: 8)
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
            .frame(width: 34, height: 34)
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
