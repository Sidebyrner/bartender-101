import SwiftUI

/// The three-button grading row shown under a flipped card during a review
/// session. Deliberately just three choices — see `ReviewGrade`'s doc
/// comment for why.
struct GradeButtons: View {
    let onGrade: (ReviewGrade) -> Void

    @State private var lastGrade: ReviewGrade?
    @State private var gradeCount = 0

    var body: some View {
        HStack(spacing: 10) {
            gradeButton(title: "Missed it", systemImage: "xmark.circle.fill", tint: .red, grade: .missed)
            gradeButton(title: "Got it", systemImage: "checkmark.circle.fill", tint: .blue, grade: .gotIt)
            gradeButton(title: "Instant", systemImage: "bolt.circle.fill", tint: .green, grade: .instant)
        }
        .sensoryFeedback(trigger: gradeCount) {
            lastGrade == .missed ? .warning : .success
        }
    }

    private func gradeButton(title: String, systemImage: String, tint: Color, grade: ReviewGrade) -> some View {
        Button {
            lastGrade = grade
            gradeCount += 1
            onGrade(grade)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.8)], startPoint: .top, endPoint: .bottom))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}
