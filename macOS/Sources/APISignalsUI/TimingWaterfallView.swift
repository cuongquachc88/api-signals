import SwiftUI
import APISignalsCore

struct TimingWaterfallView: View {
    let timing: RequestTiming
    let size: ResponseSize

    private struct Phase: Identifiable {
        let id = UUID()
        let label: String
        let value: TimeInterval?
        let color: Color
    }

    private var phases: [Phase] {
        [
            Phase(label: "DNS", value: timing.dns, color: Color.purple),
            Phase(label: "Connect", value: timing.connect, color: Color.orange),
            Phase(label: "TLS", value: timing.tls, color: Color.yellow),
            Phase(label: "TTFB", value: timing.ttfb > 0 ? timing.ttfb : nil, color: Color.dsAcc),
            Phase(label: "Download", value: timing.download > 0 ? timing.download : nil, color: Color.dsSuccess)
        ]
    }

    private var totalMs: Double { timing.total * 1000 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                timingSection
                sizeSection
            }
            .padding(DS.Spacing.lg)
        }
        .background(Color.dsSurf)
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader(title: "Timing Breakdown")

            VStack(spacing: DS.Spacing.sm) {
                ForEach(phases) { phase in
                    if let ms = phase.value.map({ $0 * 1000 }) {
                        phaseRow(phase: phase, ms: ms)
                    }
                }

                Divider().opacity(0.4)

                totalRow
            }
            .padding(DS.Spacing.md)
            .background(Color.dsBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(Color.dsBord, lineWidth: 1)
            )
        }
    }

    private func phaseRow(phase: Phase, ms: Double) -> some View {
        let fraction = totalMs > 0 ? min(ms / totalMs, 1.0) : 0

        return VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(phase.color)
                    .frame(width: 8, height: 8)
                Text(phase.label)
                    .font(DS.Font.label)
                    .foregroundStyle(Color.dsTextSec)
                    .frame(width: 70, alignment: .leading)
                Spacer()
                Text(formatMs(ms))
                    .font(DS.Font.captionMono)
                    .foregroundStyle(Color.dsTextPrim)
                    .frame(width: 80, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.dsBord.opacity(0.5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(phase.color)
                        .frame(width: geo.size.width * fraction, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var totalRow: some View {
        HStack {
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundStyle(Color.dsTextTertiary)
                .frame(width: 8, height: 8)
            Text("Total")
                .font(DS.Font.label)
                .foregroundStyle(Color.dsTextPrim)
                .frame(width: 70, alignment: .leading)
            Spacer()
            Text(formatMs(totalMs))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.dsTextPrim)
                .frame(width: 80, alignment: .trailing)
        }
    }

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader(title: "Response Size")

            VStack(spacing: DS.Spacing.sm) {
                sizeRow(label: "Headers", bytes: size.headers, color: Color.dsAcc)
                sizeRow(label: "Body", bytes: size.body, color: Color.dsSuccess)
                Divider().opacity(0.4)
                HStack {
                    Text("Total")
                        .font(DS.Font.label)
                        .foregroundStyle(Color.dsTextPrim)
                    Spacer()
                    Text(formatBytes(size.total))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.dsTextPrim)
                }
            }
            .padding(DS.Spacing.md)
            .background(Color.dsBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(Color.dsBord, lineWidth: 1)
            )
        }
    }

    private func sizeRow(label: String, bytes: Int, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(DS.Font.label)
                .foregroundStyle(Color.dsTextSec)
            Spacer()
            Text(formatBytes(bytes))
                .font(DS.Font.captionMono)
                .foregroundStyle(Color.dsTextPrim)
        }
    }

    private func formatMs(_ ms: Double) -> String {
        if ms < 1 { return String(format: "%.2f ms", ms) }
        if ms < 1000 { return String(format: "%.0f ms", ms) }
        return String(format: "%.2f s", ms / 1000)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.2f KB", Double(bytes) / 1024) }
        return String(format: "%.2f MB", Double(bytes) / (1024 * 1024))
    }
}
