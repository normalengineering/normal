import SwiftUI

struct CircleIconAvatar: View {
    let systemImage: String
    var tint: Color = .accentColor
    var size: CGFloat = DS.Size.avatar

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(DS.Opacity.subtle))
                .frame(width: size, height: size)
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
        }
    }
}
