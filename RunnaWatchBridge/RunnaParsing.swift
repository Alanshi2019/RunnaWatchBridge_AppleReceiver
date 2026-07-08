import Foundation
import Vision
import UIKit

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
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
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
        var steps: [RunnaStep] = []
        var section = ""
        var repeatIterations: Int?
        var repeatSteps: [RunnaStep] = []
        var pendingEasyPace: (String, String)?
        var pendingConversationPace = false

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

        let lines = text.components(separatedBy: .newlines)
            .map(normalize)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for line in lines {
            let lower = line.lowercased()
            if shouldIgnore(lower) { continue }
            if lower.contains("warmup") || lower.contains("warm up") { section = "warmup"; continue }
            if lower.contains("cooldown") || lower.contains("cool down") { flushRepeat(); section = "cooldown"; continue }
            if lower.contains("repeat"), let n = firstInt(in: lower) { flushRepeat(); section = "set"; repeatIterations = n; continue }
            if lower == "set" || lower.contains(" set ") || lower.hasSuffix(" set") { section = "set"; continue }
            if containsConversationPace(lower) {
                pendingConversationPace = true
            }
            if let pace = paceString(in: lower), lower.contains("no faster") {
                pendingEasyPace = (pace, easySlow.isEmpty ? pace : easySlow)
                continue
            }
            if let rest = restSeconds(in: lower) { append(RunnaStep(type: .recovery, durationSeconds: Double(rest))); continue }
            if let meters = distanceMeters(in: lower) {
                let pace = paceString(in: lower)
                var stepType: RunnaStepType = .run
                if section == "warmup" { stepType = .warmup }
                if section == "cooldown" { stepType = .cooldown }

                let isConversationPace = containsConversationPace(lower) || pendingConversationPace
                let isEasyControlled = stepType == .warmup || stepType == .cooldown || (stepType == .run && isConversationPace)

                let pMin: String?
                let pMax: String?
                if isEasyControlled {
                    pMin = pendingEasyPace?.0 ?? (easyFast.isEmpty ? nil : easyFast)
                    pMax = pendingEasyPace?.1 ?? (easySlow.isEmpty ? nil : easySlow)
                } else if let pace {
                    pMin = pace
                    pMax = pace
                } else {
                    pMin = nil
                    pMax = nil
                }
                append(RunnaStep(type: stepType, distanceMeters: meters, paceMin: pMin, paceMax: pMax, isEasyControlled: isEasyControlled))
                if section == "warmup" { section = "set" }
                pendingConversationPace = false
            }
        }
        flushRepeat()
        if steps.isEmpty { steps = placeholderSteps(easyFast: easyFast, easySlow: easySlow) }
        return RunnaWorkout(name: "Runna \(formatter.string(from: Date()))", scheduledDate: nil, steps: steps)
    }

    private static func normalize(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "|", with: " ")
        s = s.replacingOccurrences(of: "kmat", with: "km at", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "mat", with: "m at", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "8oom", with: "800m", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "6oom", with: "600m", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "4oom", with: "400m", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "2oom", with: "200m", options: .caseInsensitive)
        return s
    }

    private static func shouldIgnore(_ lower: String) -> Bool {
        ["stretches", "start workout", "athlete", "olympian", "wechat", "outdoor", "treadmill"].contains { lower.contains($0) }
    }

    private static func containsConversationPace(_ lower: String) -> Bool {
        lower.contains("conversation") || lower.contains("conversational") || lower.contains("easy run") || lower.contains("easy pace")
    }

    private static func firstInt(in s: String) -> Int? { match(#"\d+"#, in: s).flatMap(Int.init) }
    private static func paceString(in s: String) -> String? { match(#"\b\d{1,2}:[0-5]\d\b"#, in: s) }
    private static func restSeconds(in s: String) -> Int? { match(#"(\d+)\s*s(?:ec|econds)?\b.*(rest|walk|walking|recovery)"#, in: s, group: 1).flatMap(Int.init) }

    private static func distanceMeters(in s: String) -> Double? {
        guard let valueText = match(#"(\d+(?:\.\d+)?)\s*(km|k|m)\b"#, in: s, group: 1),
              let value = Double(valueText),
              let unit = match(#"(\d+(?:\.\d+)?)\s*(km|k|m)\b"#, in: s, group: 2) else { return nil }
        return unit.lowercased() == "m" ? value : value * 1000
    }

    private static func match(_ pattern: String, in s: String, group: Int = 0) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let range = Range(m.range(at: group), in: s) else { return nil }
        return String(s[range])
    }

    private static func placeholderSteps(easyFast: String, easySlow: String) -> [RunnaStep] {
        [
            RunnaStep(type: .warmup, distanceMeters: 2000, paceMin: easyFast, paceMax: easySlow, isEasyControlled: true),
            RunnaStep(type: .repeat, iterations: 4, steps: [
                RunnaStep(type: .run, distanceMeters: 400, paceMin: "5:00", paceMax: "5:00", isEasyControlled: false),
                RunnaStep(type: .run, distanceMeters: 400, paceMin: "5:40", paceMax: "5:40", isEasyControlled: false),
                RunnaStep(type: .recovery, durationSeconds: 90)
            ]),
            RunnaStep(type: .cooldown, distanceMeters: 1200, paceMin: easyFast, paceMax: easySlow, isEasyControlled: true)
        ]
    }
}
