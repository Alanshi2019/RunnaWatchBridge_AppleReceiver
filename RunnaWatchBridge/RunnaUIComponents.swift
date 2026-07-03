import SwiftUI

struct UploadPickerRow: View {
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
                .foregroundStyle(hasImage ? Color.green : Color.purple)
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
                .foregroundStyle(hasImage ? Color.green : Color.secondary)
        }
    }

    private var actionLabel: some View {
        Text(hasImage ? "Replace" : "选择")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(hasImage ? Color.primary : Color.purple)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }
}

struct StepCard: View {
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

struct LightCard<Content: View>: View {
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

struct GradientSymbol: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.title2.weight(.bold))
            .foregroundStyle(
                LinearGradient(colors: [.mint, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
    }
}

struct SlideToCreateButton: View {
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
                    .fill(LinearGradient(colors: disabled ? [Color(.systemGray3), Color(.systemGray2)] : [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: disabled ? .clear : .purple.opacity(0.25), radius: 18, x: 0, y: 10)

                HStack(spacing: 12) {
                    Spacer().frame(width: knobSize + 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.title2.bold())
                        Text(subtitle).font(.caption.weight(.medium)).opacity(0.82)
                    }
                    Spacer()
                    Image(systemName: "chevron.right.2").font(.headline.bold()).opacity(0.45).padding(.trailing, 22)
                }
                .foregroundStyle(.white)

                Circle()
                    .fill(.white)
                    .frame(width: knobSize, height: knobSize)
                    .overlay {
                        if isWorking {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.title2.bold())
                                .foregroundStyle(disabled ? Color(.systemGray2) : .purple)
                        }
                    }
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
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { dragOffset = maxOffset }
                                    action()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            dragOffset = 0
                                            didTrigger = false
                                        }
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragOffset = 0 }
                                }
                            }
                    )
            }
        }
        .frame(height: 78)
        .opacity(disabled ? 0.72 : 1)
    }
}
