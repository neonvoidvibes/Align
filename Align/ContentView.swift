import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    // Receive services from AlignApp
    @StateObject var databaseService: DatabaseService // Pass as StateObject if JournalView modifies/observes it directly
    let llmService: LLMService // Pass as simple let if JournalView only calls methods

    // State for Settings Panel
    @State private var showSettings = false
    // State for Node Info Modal
    @State private var showNodeInfo = false
    @State private var selectedNodeId: String? = nil

    // Data manager needed for Node Info
    @StateObject private var cycleData = CycleDataManager()

    // Computed property to determine if any modal/panel is showing
    private var isModalOrPanelShowing: Bool {
        showSettings || showNodeInfo
    }

    var body: some View {
        GeometryReader { geometry in
            // Use a ZStack for layering effects, content, and modals
            ZStack(alignment: .leading) {

                // Layer 1: Base Background (Always present, no effects)
                Rectangle()
                     .fill(Color(UIColor.systemBackground))
                     .ignoresSafeArea()

                // Layer 2: Main content view (Moves aside for settings, stays put for node info)
                VStack(spacing: 0) {
                    TabNavigationView(
                        currentView: $appState.currentView,
                        onSettingsClick: {
                            // Ensure only settings animation runs if node info isn't showing
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSettings.toggle()
                            }
                        }
                    )

                    // Switch between Journal and Cycle views
                    if appState.currentView == .journal {
                        // Instantiate ChatViewModel here, passing dependencies
                        // Use @StateObject if JournalView modifies it, otherwise @ObservedObject might suffice if passed down
                        JournalView()
                            .environmentObject(ChatViewModel(databaseService: databaseService, llmService: llmService))
                    } else {
                        // Pass closure to CycleView to trigger NodeInfo presentation
                        CycleView(presentNodeInfo: { nodeId in
                            selectedNodeId = nodeId
                            // Ensure only modal animation runs if settings isn't showing
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showNodeInfo = true
                            }
                        })
                        .environmentObject(cycleData)
                    }

                    Spacer()
                }
                // Background MUST be clear to reveal effect layer when active
                .background(.clear)
                .cornerRadius(showSettings ? 20 : 0) // Only round corners for settings
                .offset(x: showSettings ? geometry.size.width * 0.9 : 0) // Only offset for settings
                // Animate transforms specifically for settings state change
                .animation(.easeInOut(duration: 0.3), value: showSettings)
                // Disable interaction ONLY when NodeInfo is showing
                .disabled(showNodeInfo)
                // Add tap gesture to close Settings when it's open
                .onTapGesture {
                    if showSettings {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSettings = false
                        }
                    }
                }

                // Layer 3: Unified Effect Overlay (Blur + Dimming)
                // Always present, but opacity controlled by state.
                Rectangle() // Base shape for effects
                    .fill(.clear) // Transparent fill
                    .background(.thinMaterial) // Apply blur using material
                    .overlay( // Apply dimming on top of blur
                        Color.black.opacity(0.4)
                    )
                    .ignoresSafeArea() // Cover entire screen uniformly
                    // Allow hit testing ONLY when NodeInfo is showing (to dismiss it)
                    .allowsHitTesting(showNodeInfo)
                    .onTapGesture {
                        // Dismiss NodeInfo if tapped when showing
                        if showNodeInfo {
                             withAnimation(.easeInOut(duration: 0.3)) {
                                showNodeInfo = false
                             }
                        }
                    }
                    // Control visibility using opacity, animated by the ZStack's animation modifier
                    .opacity(isModalOrPanelShowing ? 1.0 : 0.0)
                    // Removed .transition(.opacity) as opacity modifier handles the fade

                // Layer 4: Settings panel (Slides in on top)
                if showSettings {
                    SettingsView(isPresented: $showSettings)
                        .frame(width: geometry.size.width * 0.9)
                        .transition(.move(edge: .leading))
                        .zIndex(1) // Ensure settings view is visually on top
                }

                // Layer 5: NodeInfoView modal content (Appears on top)
                if showNodeInfo, let nodeId = selectedNodeId {
                    let nodeInfo = cycleData.getNodeInfo(for: nodeId)
                    NodeInfoView(
                        isPresented: $showNodeInfo, // Pass binding
                        title: nodeInfo.title,
                        description: nodeInfo.description,
                        importance: nodeInfo.importance
                    )
                    // Center the modal
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear) // Make wrapper clear
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(2) // Ensure modal is on top of effects & settings
                }
            }
            // Animate the appearance/disappearance of conditional layers (Effect Overlay, Modals)
            .animation(.easeInOut(duration: 0.3), value: isModalOrPanelShowing)
        }
    }
}

// Previews remain the same
struct ContentView_Previews: PreviewProvider {
    // Create instances of services for the preview
    @StateObject static var previewDbService = DatabaseService()
    static let previewLlmService = LLMService.shared // Use singleton for preview too

    static var previews: some View {
        ContentView(databaseService: previewDbService, llmService: previewLlmService)
            .environmentObject(AppState())
            .environmentObject(ThemeManager())
            // Also provide db/llm service to environment if child views expect them there directly
            .environmentObject(previewDbService)
            // .environmentObject(previewLlmService) // LLMService is usually accessed via .shared
    }
}