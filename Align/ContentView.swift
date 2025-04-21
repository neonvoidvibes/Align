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
    // State for New Chat Confirmation
    @State private var showNewChatConfirmation = false
    // State for Chat History Panel
    @State private var showChatHistory = false

    // Data manager needed for Node Info
    @StateObject private var cycleData = CycleDataManager()

    // Computed property to determine if any modal/panel is showing
    private var isModalOrPanelShowing: Bool {
        showSettings || showNodeInfo || showChatHistory || showNewChatConfirmation
    }
    // Computed property for dimming overlay (excludes confirmation modal)
    private var showDimmingOverlay: Bool {
         showSettings || showNodeInfo || showChatHistory
    }
     // Computed property to disable main content interaction
     private var mainContentDisabled: Bool {
          showNodeInfo || showNewChatConfirmation || showSettings || showChatHistory
     }


    var body: some View {
        GeometryReader { geometry in
             // --- Define computed properties that use 'geometry' HERE ---
             var mainContentOffsetX: CGFloat {
                 if showSettings {
                     return geometry.size.width * 0.9
                 } else if showChatHistory {
                     return -geometry.size.width * 0.9 // Slide other way for history
                 } else {
                     return 0
                 }
             }
             var mainContentCornerRadius: CGFloat {
                 showSettings || showChatHistory ? 20 : 0
             }
             // --- End of geometry-dependent computed properties ---

            // Use a ZStack for layering effects, content, and modals
            ZStack(alignment: .leading) { // Keep leading alignment for Settings

                // Layer 0: Chat History Panel (Slides in from left) - Needs to be BEHIND main content
                // Use geometry reader's width for positioning
                 if showChatHistory {
                     ChatHistoryView(isPresented: $showChatHistory)
                         .frame(width: geometry.size.width * 0.9)
                         .transition(.move(edge: .leading)) // Adjusted from .trailing
                         .zIndex(1) // Behind main content, but above base background
                 }


                // Layer 1: Base Background (Always present, no effects) - Can be removed if panels have solid bg
                // Rectangle()
                //     .fill(Color(UIColor.systemBackground))
                //     .ignoresSafeArea()


                // Layer 2: Main content view (Moves aside for settings/history, stays put for node info/confirmation)
                VStack(spacing: 0) {
                    TabNavigationView(
                        currentView: $appState.currentView,
                        onSettingsClick: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showChatHistory = false // Close history if open
                                showSettings.toggle()
                            }
                        },
                        onNewChatClick: { // Handle new chat click
                            if appState.currentView == .journal { // Only relevant in Journal
                                 withAnimation(.easeInOut(duration: 0.3)) {
                                     showNewChatConfirmation = true
                                 }
                            } else {
                                // Optional: Switch to journal view first?
                                print("New Chat clicked outside Journal view.")
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
                // Background MUST be clear IF effect layer is used, otherwise use system background
                .background(Color(UIColor.systemBackground)) // Use solid background now
                .cornerRadius(mainContentCornerRadius) // Use computed property
                .offset(x: mainContentOffsetX) // Use computed property for offset
                // Animate transforms for BOTH settings and history state changes
                .animation(.easeInOut(duration: 0.3), value: showSettings || showChatHistory)
                // Disable interaction based on computed property
                .disabled(mainContentDisabled)
                // Add tap gesture to close Settings OR History when open
                .onTapGesture {
                    if showSettings {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSettings = false
                        }
                    }
                    if showChatHistory {
                         withAnimation(.easeInOut(duration: 0.3)) {
                            showChatHistory = false
                        }
                    }
                    // Do NOT close confirmation/node info modals on tap here
                }
                .zIndex(2) // Main content sits above history panel

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
                     .opacity(showDimmingOverlay ? 1.0 : 0.0) // Use computed property
                    // Removed .transition(.opacity) as opacity modifier handles the fade
                     .zIndex(3) // Dimming effect overlay sits above main content and side panels


                // Layer 4: Settings panel (Slides in from left)
                if showSettings {
                    SettingsView(isPresented: $showSettings)
                        .frame(width: geometry.size.width * 0.9)
                        .transition(.move(edge: .leading))
                        .zIndex(4) // Settings above main content & history
                }

                 // History panel was added as Layer 0

                // Layer 5: NodeInfoView modal content (Appears centrally)
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
                     .zIndex(5) // NodeInfo above Settings/History/Dimming

                }

                // Layer 6: New Chat Confirmation Modal (Appears centrally)
                if showNewChatConfirmation {
                     ConfirmationModal(
                         title: "Start New Chat?",
                         message: "Starting a new chat session will archive the current one.", // Adjust message as needed
                         confirmText: "Start New",
                         confirmAction: {
                             // Action: Tell ChatViewModel to start new chat
                              // Placeholder: Access ChatViewModel via environmentObject later
                              print("Confirmed: Start New Chat")
                              showNewChatConfirmation = false
                              // chatViewModel.startNewChat() // Implement this later
                         },
                         cancelAction: {
                             showNewChatConfirmation = false
                         }
                     )
                     .transition(.opacity.combined(with: .scale(scale: 0.95)))
                     .zIndex(6) // Highest level modal
                }
            }
            // Animate the appearance/disappearance of conditional layers (Effect Overlay, Modals, Panels)
            .animation(.easeInOut(duration: 0.3), value: isModalOrPanelShowing) // Use combined state
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