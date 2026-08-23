import SwiftUI

/// Hour + minute wheels for picking an arbitrary duration, matching the shape
/// of Screen Time's own App Limits picker.
///
/// Deliberately permits any value in range including zero — callers validate
/// minimums in a section footer, the way `ScheduleFormSheet` does.
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
                options: hourOptions,
                selection: binding(get: { $0 / 60 }, set: { $1 * 60 + $0 % 60 }),
                unit: "hr",
                identifier: "hours"
            )
            wheel(
                "Minutes",
                options: minuteOptions,
                selection: binding(get: { $0 % 60 }, set: { $0 / 60 * 60 + $1 }),
                unit: "min",
                identifier: "minutes"
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func wheel(
        _ label: LocalizedStringKey,
        options: [Int],
        selection: Binding<Int>,
        unit: LocalizedStringKey,
        identifier: String
    ) -> some View {
        Picker(label, selection: selection) {
            ForEach(options, id: \.self) { value in
                Text("\(value) \(Text(unit))").tag(value)
            }
        }
        .pickerStyle(.wheel)
        .accessibilityIdentifier(identifierPrefix.map { "\($0).\(identifier)" } ?? identifier)
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
