import SwiftUI

struct WeekdayPickerView: View {
    @Binding var selected: Set<Int>

    private let days: [(Int, String)] = {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return (1 ... 7).map { ($0, symbols[$0 - 1]) }
    }()

    var body: some View {
        HStack(spacing: DS.Spacing.sm - 2) {
            ForEach(days, id: \.0) { day, symbol in
                WeekdayButton(
                    day: day,
                    symbol: symbol,
                    isOn: selected.contains(day),
                    onTap: { toggle(day) }
                )
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private func toggle(_ day: Int) {
        if selected.contains(day) {
            selected.remove(day)
        } else {
            selected.insert(day)
        }
    }
}

private struct WeekdayButton: View {
    let day: Int
    let symbol: String
    let isOn: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(symbol)
                .font(.caption.weight(.bold))
                .frame(width: DS.Size.chipHeight, height: DS.Size.chipHeight)
                .foregroundStyle(isOn ? .white : .primary)
                .background(
                    Circle().fill(isOn ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
