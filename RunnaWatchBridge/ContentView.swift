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
    @State private var easyFast = "5:50"
    @State private var easySlow = "6:30"

    private var statusPill: String {
        if status.contains("完成") || status.contains("就位") { return "已就位" }
        if status.contains("失败") || status.contains("错误") || status.contains("搞坏") { return "出事了" }
        if isWorking { return "识别中" }
        return "未识别"
    }

    private var statusColor: Color {
        if statusPill == "出事了" { return .red }
        if statusPill == "已就位" { return .white }
        return .secondary
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RunnaBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        uploadCard
                        resultCard
                        paceCard
                        watchCard
                        actionButton
                        privacyFooter
                        ocrDisclosure
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                    .padding(.bottom, 42)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Circle()
                .fill(.white.opacity(0.10))
                .overlay(
                    Text("🐱")
                        .font(.system(size: 34))
                )
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                .shadow(color: .white.opacity(0.08), radius: 16, x: 0, y: 0)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("不逃跑计划")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("v7.0")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
                }
                Text("Runna → Apple Watch")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))

                HStack(spacing: 8) {
                    Capsule().fill(.white).frame(width: 42, height: 4)
                    Capsule().fill(.white.opacity(0.22)).frame(width: 32, height: 4)
                    Capsule().fill(.white.opacity(0.14)).frame(width: 32, height: 4)
                }
                .padding(.top, 4)
            }
            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
                Image(systemName: "waveform.path.ecg")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
        }
        .padding(.bottom, 6)
    }

    private var uploadCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("上传 Runna 截图")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("识别你的训练计划")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    SpeechBubble(text: "上传看看！")
                }

                HStack(alignment: .center, spacing: 18) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 30, weight: .semibold))
                            Text(selectedImage == nil ? "选择图片" : "重新选择")
                                .font(.headline)
                            Text("支持长截图")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.44))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 160)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [7, 6]))
                                .foregroundStyle(.white.opacity(0.45))
                        )
                        .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task { await loadImage(from: newItem) }
                    }

                    StrictCatView()
                        .frame(width: 145, height: 150)
                }

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .frame(maxHeight: 240)
                        .frame(maxWidth: .infinity)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1))
                }
            }
        }
    }

    private var resultCard: some View {
        DarkCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("识别结果", systemImage: "viewfinder")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(statusPill)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusPill == "出事了" ? .red : .white.opacity(0.72))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.09), in: Capsule())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 15)

                Divider().overlay(.white.opacity(0.12))

                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout?.name ?? "尚未识别训练计划")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(status)
                            .font(.callout)
                            .foregroundStyle(statusColor.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    OrbitView()
                        .frame(width: 128, height: 96)
                }
                .padding(18)
            }
        }
    }

    private var paceCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("配速设置", systemImage: "speedometer")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Label("建议配速", systemImage: "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
                }

                HStack(spacing: 14) {
                    paceTile(title: "Easy Pace", icon: "face.smiling", text: $easyFast, placeholder: "5:50")
                    paceTile(title: "Slow Pace", icon: "tortoise", text: $easySlow, placeholder: "6:30")
                }
            }
        }
    }

    private var watchCard: some View {
        DarkCard {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("设备连接", systemImage: "applewatch")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Apple Watch")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        Circle().fill(.white).frame(width: 8, height: 8)
                        Text("准备接入")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                Spacer()
                WatchGlyph()
                    .frame(width: 118, height: 110)
            }
        }
    }

    private var actionButton: some View {
        Button {
            Task { await recognizeBuildAndSchedule() }
        } label: {
            HStack(spacing: 12) {
                if isWorking {
                    ProgressView().tint(.black)
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.headline)
                }
                Text(isWorking ? "创建中..." : "创建并发送到 Apple Watch")
                    .font(.headline.weight(.bold))
                Spacer(minLength: 0)
                Image(systemName: "paperplane.fill")
                    .font(.headline)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(selectedImage == nil || isWorking ? 0.45 : 1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .white.opacity(selectedImage == nil ? 0 : 0.22), radius: 16, x: 0, y: 0)
        }
        .disabled(selectedImage == nil || isWorking)
        .buttonStyle(.plain)
    }

    private var privacyFooter: some View {
        Label("所有数据在本地处理，保护你的隐私", systemImage: "lock.fill")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.42))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var ocrDisclosure: some View {
        if !ocrText.isEmpty {
            DisclosureGroup {
                TextEditor(text: $ocrText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } label: {
                Label("识别文本", systemImage: "text.viewfinder")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(16)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.14), lineWidth: 1))
        }
    }

    private func paceTile(title: String, icon: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                Spacer()
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.75))
            }
            TextField(placeholder, text: text)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
            Text("min / km")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.42))
            Capsule()
                .fill(.white)
                .frame(width: 42, height: 3)
                .overlay(alignment: .trailing) {
                    Capsule().fill(.white.opacity(0.16)).frame(width: 96, height: 3).offset(x: 96)
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.17), lineWidth: 1))
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
                    status = "截图已就位。严厉小猫开始盯着你。"
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

private struct DarkCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.white.opacity(0.045))
                    .background(.ultraThinMaterial.opacity(0.18), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            )
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)
    }
}

private struct RunnaBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [.white.opacity(0.08), .clear], center: .topLeading, startRadius: 20, endRadius: 360)
                .ignoresSafeArea()
            RadialGradient(colors: [.white.opacity(0.055), .clear], center: .bottomTrailing, startRadius: 60, endRadius: 440)
                .ignoresSafeArea()
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}

private struct SpeechBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.white.opacity(0.055), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.32), lineWidth: 1))
            .rotationEffect(.degrees(-7))
    }
}

private struct StrictCatView: View {
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(.white.opacity(0.65)).frame(height: 1)
                    .padding(.horizontal, 4)
                Text("识别更准更快")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
                    .padding(.top, 10)
            }
            Text("😾")
                .font(.system(size: 74))
                .offset(y: 6)
                .shadow(color: .white.opacity(0.14), radius: 12, x: 0, y: 0)
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .offset(x: -50, y: -42)
            Image(systemName: "sparkles")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .offset(x: 52, y: -34)
        }
    }
}

private struct OrbitView: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Ellipse()
                    .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                    .frame(width: CGFloat(92 + i * 18), height: CGFloat(42 + i * 10))
                    .rotationEffect(.degrees(Double(i * 18)))
            }
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.74), lineWidth: 1.4)
                .frame(width: 44, height: 44)
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(.white)
                .font(.headline)
            Circle().fill(.white).frame(width: 8, height: 8).offset(x: 46, y: -24)
            Circle().fill(.white.opacity(0.75)).frame(width: 6, height: 6).offset(x: -52, y: 18)
        }
    }
}

private struct WatchGlyph: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(.white.opacity(Double(3 - i) * 0.035), lineWidth: 1)
                    .frame(width: CGFloat(70 + i * 24), height: CGFloat(70 + i * 24))
            }
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(.white.opacity(0.8), lineWidth: 3)
                .frame(width: 58, height: 74)
            RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.72)).frame(width: 28, height: 10).offset(y: -46)
            RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.72)).frame(width: 28, height: 10).offset(y: 46)
            Image(systemName: "checkmark")
                .font(.title2.bold())
                .foregroundStyle(.white)
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
