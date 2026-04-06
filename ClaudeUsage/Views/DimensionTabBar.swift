import SwiftUI

struct DimensionTabBar: View {
    @Binding var selectedDimension: TimeDimension

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeDimension.allCases) { dim in
                Button(action: { selectedDimension = dim }) {
                    VStack(spacing: 0) {
                        Text(dim.tabLabel)
                            .font(.system(size: 11))
                            .foregroundColor(selectedDimension == dim ? .accent : .textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.spacing8)
                        Rectangle()
                            .fill(selectedDimension == dim ? Color.accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.background)
    }
}
