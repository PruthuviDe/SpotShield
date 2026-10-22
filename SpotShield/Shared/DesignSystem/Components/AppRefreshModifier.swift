import SwiftUI

struct AppRefreshModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    let action: @MainActor () async -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                isVisible = true
                Task { await action() }
            }
            .onDisappear {
                isVisible = false
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, isVisible else { return }
                Task { await action() }
            }
    }
}

extension View {
    func refreshOnAppearAndForeground(
        _ action: @escaping @MainActor () async -> Void
    ) -> some View {
        modifier(AppRefreshModifier(action: action))
    }
}
