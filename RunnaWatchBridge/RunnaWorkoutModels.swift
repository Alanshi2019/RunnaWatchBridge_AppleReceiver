import Foundation

struct RunnaWorkout: Codable {
    var name: String
    var scheduledDate: Date?
    var steps: [RunnaStep]
}

struct RunnaStep: Codable, Identifiable {
    var id = UUID()
    var type: RunnaStepType
    var distanceMeters: Double?
    var durationSeconds: Double?
    var paceMin: String?
    var paceMax: String?
    var iterations: Int?
    var steps: [RunnaStep]?

    enum CodingKeys: String, CodingKey {
        case type, distanceMeters, durationSeconds, paceMin, paceMax, iterations, steps
    }
}

enum RunnaStepType: String, Codable {
    case warmup
    case run
    case rest
    case recovery
    case cooldown
    case `repeat`
}

enum RunnaJSON {
    static func decode(_ text: String) throws -> RunnaWorkout {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RunnaWorkout.self, from: Data(text.utf8))
    }
}

extension RunnaStep {
    var summary: String {
        switch type {
        case .repeat:
            return "Repeat \(iterations ?? 1)x"
        case .rest, .recovery:
            return "Rest \(Int(durationSeconds ?? 0))s"
        case .warmup:
            return "Warm up \(Int(distanceMeters ?? 0))m"
        case .cooldown:
            return "Cool down \(Int(distanceMeters ?? 0))m"
        case .run:
            return "Run \(Int(distanceMeters ?? 0))m @ \(paceMin ?? "-")"
        }
    }
}
