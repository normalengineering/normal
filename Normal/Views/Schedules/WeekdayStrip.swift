import SwiftUI

struct WeekdayStrip: View {
    let weekdays: Set<Int>
    @ScaledMetric(relativeTo: .caption2) private var chipWidth: CGFloat = 22

    private var accessibilityDays: String {
        let names = Calendar.current.weekdaySymbols
        return weekdays.sorted()
            .filter { (1...7).contains($0) }
            .map { names[$0 - 1] }
            .formatted(.list(type: .and))
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(1...7, id: \.self) { day in
                let isOn = weekdays.contains(day)
                Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                    .font(.caption2.weight(.medium))
                    .frame(minWidth: chipWidth)
                    .padding(.vertical, DS.Spacing.xs - 1)
                    .foregroundStyle(isOn ? Color.primary : Color.secondary)
                    .background(isOn ? Color.accentColor.opacity(DS.Opacity.muted) : Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDays)
    }
}
