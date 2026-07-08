import SwiftUI

struct EditableStep {
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
            steps: type == .repeat ? [
                RunnaStep(type: .run, distanceMeters: Double(distanceMeters) ?? 400, durationSeconds: nil, paceMin: paceMin.isEmpty ? nil : paceMin, paceMax: paceMax.isEmpty ? nil : paceMax, iterations: nil, steps: nil)
            ] : nil
        )
    }
}

struct StepEditorView: View {
    @Binding var draft: EditableStep
    let easyFast: String
    let easySlow: String
    let onSave: () -> Void

    private var isPaceControlledByEasyZone: Bool {
        if draft.type == .warmup || draft.type == .cooldown { return true }
        guard draft.type == .run else { return false }
        if draft.paceMin.isEmpty && draft.paceMax.isEmpty { return true }
        return draft.paceMin != draft.paceMax
    }

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
                    TextField("Pace min", text: paceMinBinding)
                        .keyboardType(.numbersAndPunctuation)
                        .disabled(isPaceControlledByEasyZone)
                    TextField("Pace max", text: paceMaxBinding)
                        .keyboardType(.numbersAndPunctuation)
                        .disabled(isPaceControlledByEasyZone)
                    if isPaceControlledByEasyZone {
                        Text("Controlled by Easy Pace Zone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

    private var paceMinBinding: Binding<String> {
        Binding(
            get: { isPaceControlledByEasyZone ? easyFast : draft.paceMin },
            set: { draft.paceMin = $0 }
        )
    }

    private var paceMaxBinding: Binding<String> {
        Binding(
            get: { isPaceControlledByEasyZone ? easySlow : draft.paceMax },
            set: { draft.paceMax = $0 }
        )
    }
}
