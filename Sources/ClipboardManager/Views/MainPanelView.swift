import SwiftUI

// MARK: - MainPanelView

struct MainPanelView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Frosted glass background with rounded corners
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)

            HStack(spacing: 0) {
                // Left: category sidebar
                SidebarView(viewModel: viewModel)
                    .frame(width: 175)

                Divider()

                // Center: search + list
                ClipboardListView(viewModel: viewModel, onDismiss: onDismiss)

                Divider()

                // Right: preview panel
                PreviewPanelView(viewModel: viewModel, onDismiss: onDismiss)
                    .frame(width: 255)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(width: 820, height: 560)
        .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 10)
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
    }
}
