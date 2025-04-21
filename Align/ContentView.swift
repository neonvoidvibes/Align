import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    // Receive services from AlignApp
    @StateObject var databaseService: DatabaseService
    let llmService: LLMService
    // Create ChatViewModel here to be passed down
    @StateObject private var chatViewModel: ChatViewModel

    // State for Settings Panel
    @State private var showSettings = false
    // State for Node Info Modal
    @State private var showNodeInfo = false
    @State private var selectedNodeId: String? = nil
    // State for New Chat Confirmation
    @State private var showNewChatConfirmation = false
    // State for Chat History Panel (Not implemented as panel yet)
    @State private var showChatHistory = false // Placeholder state if needed later

    // Data manager needed for Node Info
    @StateObject private var cycleData = CycleDataManager() // Keep for Loop view

    // Initialize ChatViewModel in init
    init(databaseService: DatabaseService, llmService: LLMService) {
        _databaseService = StateObject(wrappedValue: databaseService) // Use StateObject init syntax
        self.llmService = llmService
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(databaseService: databaseService, llmService: llmService))
    }

    // Computed property to determine if any modal/panel is showing
    private var isModalOrPanelShowing: Bool {
        showSettings || showNodeInfo || showChatHistory || showNewChatConfirmation
    }
    // Computed property for dimming overlay (excludes confirmation modal)
    private var showDimmingOverlay: Bool {
         // Include confirmation modal in dimming
         showSettings || showNodeInfo || showChatHistory || showNewChatConfirmation
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
                 } else if showChatHistory { // Placeholder logic if history becomes a panel
                     return -geometry.size.width * 0.9
                 } else {
                     return 0
                 }
             }
             var mainContentCornerRadius: CGFloat {
                 showSettings || showChatHistory ? 20 : 0 // Placeholder logic if history becomes a panel
             }
             // --- End of geometry-dependent computed properties ---

            // Use a ZStack for layering effects, content, and modals
            ZStack(alignment: .leading) { // Keep leading alignment for Settings

                // Layer 0: Chat History Panel (Placeholder - Currently handled by main view switch)
                // if showChatHistory { ... }

                // Layer 1: Base Background (Always present, no effects) - Can be removed if panels have solid bg
                 Rectangle()
                     .fill(Color(UIColor.systemBackground))
                     .ignoresSafeArea()


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

                    // Switch between History, Journal, and Loop views
                    switch appState.currentView {
                    case .history:
                         // Use the ChatHistoryView shell - controlled by main view state
                         ChatHistoryView(isPresented: .constant(true)) // Needs adjustment later if controlled by side panel
                    case .journal:
                         // JournalView now gets ChatViewModel from environment
                         JournalView()
                    case .loop:
                         // Pass closure to CycleView to trigger NodeInfo presentation
                         CycleView(presentNodeInfo: { nodeId in
                             selectedNodeId = nodeId
                             withAnimation(.easeInOut(duration: 0.3)) {
                                 showNodeInfo = true
                             }
                         })
                    } // End switch appState.currentView

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
                    if showChatHistory { // Placeholder logic
                         withAnimation(.easeInOut(duration: 0.3)) {
                            showChatHistory = false
                        }
                    }
                    // Do NOT close confirmation/node info modals on tap here
                }
                .zIndex(2) // Main content sits above history panel

                // Unified Dimming/Blur effect controlled by showDimmingOverlay
                 Rectangle() // Base shape for effects
                     .fill(.clear) // Transparent fill
                     .background(.thinMaterial) // Apply blur using material
                     .overlay( // Apply dimming on top of blur
                         Color.black.opacity(0.4)
                     )
                     .ignoresSafeArea() // Cover entire screen uniformly
                     .allowsHitTesting(showNodeInfo || showSettings || showChatHistory) // Allow taps for panels too
                     .onTapGesture {
                         // Dismiss NodeInfo if tapped when showing
                         if showNodeInfo {
                              withAnimation(.easeInOut(duration: 0.3)) {
                                 showNodeInfo = false
                              }
                         }
                         // Dismiss settings or history if they are panels and tap outside
                         if showSettings {
                              withAnimation(.easeInOut(duration: 0.3)) { showSettings = false }
                         }
                         // if showChatHistory { ... } // Add if history becomes a panel
                     }
                     .opacity(showDimmingOverlay ? 1.0 : 0.0) // Control visibility
                     .zIndex(3) // Ensure it's above panels but below modals


                // Layer 4: Settings panel (Slides in from left)
                if showSettings {
                    SettingsView(isPresented: $showSettings)
                        .frame(width: geometry.size.width * 0.9)
                        .transition(.move(edge: .leading))
                        .zIndex(4) // Settings above main content & history
                }

                 // History panel was added as Layer 0 - Handled by main view switch for now

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
                              chatViewModel.startNewChat() // Call the actual function
                              print("Confirmed: Start New Chat action executed.")
                              showNewChatConfirmation = false
                         },
                         cancelAction: {
                             showNewChatConfirmation = false
                         }
                     )
                     // Center the modal using a frame that fills the screen
                     .frame(maxWidth: .infinity, maxHeight: .infinity)
                     .background(Color.clear) // Ensure wrapper is clear
                     .transition(.opacity.combined(with: .scale(scale: 0.95)))
                     .zIndex(6) // Highest level modal
                }

            } // End ZStack
            // Provide ChatViewModel and CycleData to the environment for child views within the ZStack
            .environmentObject(chatViewModel)
            .environmentObject(cycleData)
            // Animate the appearance/disappearance of conditional layers (Effect Overlay, Modals, Panels)
            .animation(.easeInOut(duration: 0.3), value: isModalOrPanelShowing) // Use combined state

        } // End GeometryReader
    } // End body
} // End struct

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
