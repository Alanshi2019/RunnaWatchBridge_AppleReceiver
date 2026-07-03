import Foundation
import WorkoutKit

@available(iOS 17.0, *)
enum WorkoutKitBuilder {
    static func build(from runna: RunnaWorkout) throws -> CustomWorkout {
        var warmup: WorkoutStep? = nil
        var cooldown: WorkoutStep? = nil
        var blocks: [IntervalBlock] = []
        var looseSteps: [IntervalStep] = []

        func flushLooseSteps() {
            if !looseSteps.isEmpty {
                blocks.append(IntervalBlock(steps: looseSteps, iterations: 1))
                looseSteps.removeAll()
            }
        }

        for step in runna.steps {
            switch step.type {
            case .warmup:
                warmup = workoutStep(for: step)
            case .cooldown:
                flushLooseSteps()
                cooldown = workoutStep(for: step)
            case .run:
                looseSteps.append(IntervalStep(.work, step: workoutStep(for: step)))
            case .rest, .recovery:
                looseSteps.append(IntervalStep(.recovery, step: workoutStep(for: step)))
            case .repeat:
                flushLooseSteps()
                let nested = (step.steps ?? []).map { child -> IntervalStep in
                    switch child.type {
                    case .rest, .recovery:
                        return IntervalStep(.recovery, step: workoutStep(for: child))
                    default:
                        return IntervalStep(.work, step: workoutStep(for: child))
                    }
                }
                blocks.append(IntervalBlock(steps: nested, iterations: step.iterations ?? 1))
            }
        }

        flushLooseSteps()

        return CustomWorkout(
            activity: .running,
            location: .outdoor,
            displayName: runna.name,
            warmup: warmup,
            blocks: blocks,
            cooldown: cooldown
        )
    }

    private static func workoutStep(for step: RunnaStep) -> WorkoutStep {
        if let alert = paceAlert(for: step) {
            return WorkoutStep(goal: goal(for: step), alert: alert)
        }
        return WorkoutStep(goal: goal(for: step))
    }

    private static func goal(for step: RunnaStep) -> WorkoutGoal {
        if let meters = step.distanceMeters {
            return .distance(meters, .meters)
        }
        if let seconds = step.durationSeconds {
            return .time(seconds, .seconds)
        }
        return .open
    }

    private static func paceAlert(for step: RunnaStep) -> SpeedRangeAlert? {
        guard let paceMin = step.paceMin, let fast = metersPerSecond(fromPace: paceMin) else {
            return nil
        }

        let slow = step.paceMax.flatMap { metersPerSecond(fromPace: $0) } ?? fast
        guard fast.isFinite, slow.isFinite, fast > 0, slow > 0 else { return nil }

        var lower = min(fast, slow)
        var upper = max(fast, slow)

        // WorkoutKit crashes with unsupportedRange when speed range has zero width.
        // This happens when OCR/manual edit gives an exact pace like 5:00...5:00.
        let minimumWidth = 0.05
        if upper - lower < minimumWidth {
            let center = (upper + lower) / 2
            lower = max(0.01, center - minimumWidth / 2)
            upper = center + minimumWidth / 2
        }

        return .speed(lower...upper, unit: .metersPerSecond, metric: .current)
    }

    private static func metersPerSecond(fromPace pace: String) -> Double? {
        let parts = pace.split(separator: ":")
        guard parts.count == 2,
              let minutes = Double(parts[0]),
              let seconds = Double(parts[1]) else {
            return nil
        }
        let totalSeconds = minutes * 60 + seconds
        guard totalSeconds > 0 else { return nil }
        return 1000.0 / totalSeconds
    }
}
