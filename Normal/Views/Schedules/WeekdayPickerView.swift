import SwiftUI

struct WeekdayPickerView: View {
    @Binding var selected: Set<Int>

    private let days: [(Int, String)] = {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return (1 ... 7).map { ($0, symbols[$0 - 1]) }
    }()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.0) { day, symbol in
                let isOn = selected.contains(day)

                Button {
                    if isOn {
                        selected.remove(day)
                    } else {
                        selected.insert(day)
                    }
                } label: {
                    Text(symbol)
                        .font(.caption.weight(.bold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(isOn ? .white : .primary)
                        .background(
                            Circle()
                                .fill(isOn ? Color.accentColor : Color(.tertiarySystemFill))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Calendar.current.weekdaySymbols[day - 1]
                )
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
