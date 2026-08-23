import SwiftUI

struct DurationWheelPicker: View {
    @Binding var minutes: Int

    let maxMinutes: Int
    var minuteStep = 5
    var identifierPrefix: String?

    private var hourOptions: [Int] { Array(0 ... (maxMinutes / 60)) }
    private var minuteOptions: [Int] { Array(stride(from: 0, to: 60, by: minuteStep)) }

    var body: some View {
        HStack(spacing: 0) {
            wheel(
                "Hours",
                unit: "hr",
                options: hourOptions,
                selection: binding(get: { $0 / 60 }, set: { $1 * 60 + $0 % 60 }),
                identifier: "hours"
            )
            wheel(
                "Minutes",
                unit: "min",
                options: minuteOptions,
                selection: binding(get: { $0 % 60 }, set: { $0 / 60 * 60 + $1 }),
                identifier: "minutes"
            )
        }
    }

    private func wheel(
        _ title: LocalizedStringKey,
        unit: LocalizedStringKey,
        options: [Int],
        selection: Binding<Int>,
        identifier: String
    ) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { value in
                    Text(verbatim: "\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .accessibilityLabel(title)
            .accessibilityIdentifier(identifierPrefix.map { "\($0).\(identifier)" } ?? identifier)
            Text(unit)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    /// Projects one wheel onto the shared total, clamped to the picker's range.
    private func binding(
        get component: @escaping (Int) -> Int,
        set combine: @escaping (Int, Int) -> Int
    ) -> Binding<Int> {
        Binding(
            get: { component(minutes) },
            set: { minutes = min(max(combine(minutes, $0), 0), maxMinutes) }
        )
    }
}
