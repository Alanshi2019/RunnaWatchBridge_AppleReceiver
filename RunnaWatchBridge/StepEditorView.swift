import SwiftUI

struct EditableStep {
    var type: RunnaStepType = .run
    var distanceMeters: String = "400"
    var durationSeconds: String = "90"
    var paceMin: String = "5:45"
    var paceMax: String = "6:30"
    var iterations: String = "1"
    var isEasyControlled: Bool = false
    var childSteps: [RunnaStep]?

    init() {}

    init(step: RunnaStep) {
        type = step.type
        distanceMeters = step.distanceMeters.map { String(Int($0)) } ?? ""
        durationSeconds = step.durationSeconds.map { String(Int($0)) } ?? ""
        paceMin = step.paceMin ?? ""
        paceMax = step.paceMax ?? ""
        iterations = step.iterations.map(String.init) ?? "1"
        isEasyControlled = step.isEasyControlled == true
        childSteps = step.steps
    }

    func toRunnaStep() -> RunnaStep {
        RunnaStep(
            type: type,
            distanceMeters: type == .repeat ? nil : Double(distanceMeters),
            durationSeconds: type == .repeat ? nil : Double(durationSeconds),
            paceMin: type == .repeat ? nil : (paceMin.isEmpty ? nil : paceMin),
            paceMax: type == .repeat ? nil : (paceMax.isEmpty ? nil : paceMax),
            iterations: type == .repeat ? Int(iterations) : nil,
            steps: type == .repeat ? childSteps : nil,
            isEasyControlled: type == .run ? isEasyControlled : nil
        )
    }
}

struct StepEditorView: View {
    @Binding var draft: EditableStep
    let easyFast: String
    let easySlow: String
    let onSave: () -> Void

    private var isPaceControlledByEasyZone: Bool {
        draft.type == .warmup || draft.type == .cooldown || (draft.type == .run && draft.isEasyControlled)
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
                        if let childSteps = draft.childSteps, !childSteps.isEmpty {
                            Text("Child steps are edited from the workout list below the Repeat card.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(childSteps) { child in
                                Text(child.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
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
