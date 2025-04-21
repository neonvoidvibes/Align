import SwiftUI

struct ConfirmationModal: View {
    // Properties matching notetoself for reusability
    var title: String
    var message: String
    var confirmText: String
    var cancelText: String = "Cancel"
    var confirmAction: () -> Void
    var cancelAction: () -> Void
    var isDestructive: Bool = false

    @EnvironmentObject private var themeManager: ThemeManager // Use Align's ThemeManager

    var body: some View {
        // Similar structure to NodeInfoView - content on a background panel
        VStack(alignment: .center, spacing: 16) { // Center align content
            Text(title)
                .font(.futura(size: 20, weight: .bold)) // Slightly smaller title
                .foregroundColor(.primary)

            Text(message)
                .font(.futura(size: 16)) // Smaller body text
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center) // Center align message
                .padding(.horizontal)

            // Buttons side-by-side
            HStack(spacing: 12) {
                // Cancel Button (Secondary Style)
                Button(action: {
                    cancelAction()
                }) {
                    Text(cancelText)
                        .font(.futura(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.primary) // Use primary text color
                        .background(Color(UIColor.systemGray5)) // Subtle background
                        .cornerRadius(8)
                }

                // Confirm Button (Primary/Destructive Style)
                Button(action: {
                    confirmAction()
                }) {
                    Text(confirmText)
                        .font(.futura(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(isDestructive ? .white : .black) // Contrast text
                        .background(isDestructive ? Color.red : themeManager.accentColor) // Destructive or accent
                        .cornerRadius(8)
                }
            }
            .padding(.top, 10) // Space above buttons

        }
        .padding() // Padding inside the modal content
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground)) // Use system background
                .shadow(radius: 10)
        )
        // Constrain modal size
        .frame(width: UIScreen.main.bounds.width * 0.85) // Slightly wider than NodeInfo
        .fixedSize(horizontal: false, vertical: true) // Allow height to adjust
    }
}

// Preview
struct ConfirmationModal_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
             Color.black.opacity(0.4).ignoresSafeArea() // Dimmed background for preview

             ConfirmationModal(
                 title: "Start New Chat?",
                 message: "Starting a new chat will archive the current conversation.",
                 confirmText: "New Chat",
                 confirmAction: { print("Confirm") },
                 cancelAction: { print("Cancel") },
                 isDestructive: false // Example non-destructive
             )
             .environmentObject(ThemeManager())
        }
    }
}