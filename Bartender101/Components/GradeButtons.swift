import SwiftUI

/// The three-button grading row shown under a flipped card during a review
/// session. Deliberately just three choices — see `ReviewGrade`'s doc
/// comment for why.
struct GradeButtons: View {
    let onGrade: (ReviewGrade) -> Void

    var body: some View {
        HStack(spacing: 10) {
            gradeButton(title: "Missed it", systemImage: "xmark.circle.fill", tint: .red, grade: .missed)
            gradeButton(title: "Got it", systemImage: "checkmark.circle.fill", tint: .blue, grade: .gotIt)
            gradeButton(title: "Instant", systemImage: "bolt.circle.fill", tint: .green, grade: .instant)
        }
    }

    private func gradeButton(title: String, systemImage: String, tint: Color, grade: ReviewGrade) -> some View {
        Button {
            onGrade(grade)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}
