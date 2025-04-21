import SwiftUI

// Add notification name extension here or in a dedicated file
extension Notification.Name {
    static let switchToTabNotification = Notification.Name("SwitchToTabNotification")
    // Add other notification names here if needed later
}


struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    // --- Declare properties passed from AlignApp ---
    @StateObject var databaseService: DatabaseService // Correctly declared with @StateObject
    let llmService: LLMService                 // Correctly declared as let

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
    @StateObject private var cycleData: CycleDataManager // Correctly declared before init

    // Initialize ChatViewModel and other StateObjects in init
    init(databaseService: DatabaseService, llmService: LLMService) {
        // Use _property = StateObject(wrappedValue: ...) syntax for StateObjects
        _databaseService = StateObject(wrappedValue: databaseService)
        self.llmService = llmService // Assign non-StateObject property directly
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(databaseService: databaseService, llmService: llmService))
        // cycleData is also a StateObject and needs init here if not assigned default value
        _cycleData = StateObject(wrappedValue: CycleDataManager())
    }

    // Computed property to determine if any modal/panel is showing
    private var isModalOrPanelShowing: Bool {
        showSettings || showNodeInfo || showChatHistory || showNewChatConfirmation
    }
    // Computed property for dimming overlay (includes confirmation modal)
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
                     // Note: History is currently shown via main view switch, not a panel.
                     // Keeping this logic structure in case it changes later.
                     return 0 // -geometry.size.width * 0.9
                 } else {
                     return 0
                 }
             }
             var mainContentCornerRadius: CGFloat {
                  // Apply corner radius only if settings panel is showing
                  // History view doesn't use a sliding panel currently.
                 showSettings ? 20 : 0
             }
             // --- End of geometry-dependent computed properties ---

            // Use a ZStack for layering effects, content, and modals
            ZStack(alignment: .leading) { // Keep leading alignment for Settings

                // Layer 0: Chat History Panel (Not used currently, view is switched)

                // Layer 1: Base Background
                 Rectangle()
                     .fill(Color(UIColor.systemBackground))
                     .ignoresSafeArea()

                // Layer 2: Main content view
                VStack(spacing: 0) {
                    TabNavigationView(
                        currentView: $appState.currentView,
                        onSettingsClick: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                // showChatHistory = false // History not a panel currently
                                showSettings.toggle()
                            }
                        },
                        onNewChatClick: { // Handle new chat click
                            if appState.currentView == .journal { // Only relevant in Journal
                                 withAnimation(.easeInOut(duration: 0.3)) {
                                     showNewChatConfirmation = true
                                 }
                            } else {
                                print("New Chat clicked outside Journal view.")
                            }
                        }
                    )

                    // Switch between Notes, Journal, and Loop views
                    switch appState.currentView {
                    case .notes: // Renamed from history
                         // Display the new NotesView
                         NotesView() // Gets ChatViewModel from environment
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
                .background(Color(UIColor.systemBackground)) // Use solid background
                .cornerRadius(mainContentCornerRadius) // Use computed property
                .offset(x: mainContentOffsetX) // Use computed property for offset
                .animation(.easeInOut(duration: 0.3), value: showSettings) // Animate only for settings
                .disabled(mainContentDisabled)
                .onTapGesture { // Tap main content to close Settings panel
                    if showSettings {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSettings = false
                        }
                    }
                    // History not a panel, confirmation/nodeinfo shouldn't close on main content tap
                }
                .zIndex(2) // Main content sits above potential future history panel

                // Unified Dimming/Blur effect controlled by showDimmingOverlay
                 Rectangle() // Base shape for effects
                     .fill(.clear) // Transparent fill
                     .background(.thinMaterial) // Apply blur using material
                     .overlay( // Apply dimming on top of blur
                         Color.black.opacity(0.4)
                     )
                     .ignoresSafeArea() // Cover entire screen uniformly
                      // Allow taps only for NodeInfo/Settings dismissal for now
                     .allowsHitTesting(showNodeInfo || showSettings)
                     .onTapGesture {
                         // Dismiss NodeInfo if tapped when showing
                         if showNodeInfo {
                              withAnimation(.easeInOut(duration: 0.3)) {
                                 showNodeInfo = false
                              }
                         }
                         // Dismiss settings if tapped outside panel
                         if showSettings {
                              withAnimation(.easeInOut(duration: 0.3)) { showSettings = false }
                         }
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

                // Layer 5: NodeInfoView modal content (Appears centrally)
                if showNodeInfo, let nodeId = selectedNodeId {
                    let nodeInfo = cycleData.getNodeInfo(for: nodeId)
                    NodeInfoView(
                        isPresented: $showNodeInfo, // Pass binding
                        title: nodeInfo.title,
                        description: nodeInfo.description,
                        importance: nodeInfo.importance
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Center the modal
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
                              chatViewModel.startNewChat() // Call the actual function
                              print("Confirmed: Start New Chat action executed.")
                              showNewChatConfirmation = false
                         },
                         cancelAction: {
                             showNewChatConfirmation = false
                         }
                     )
                     .frame(maxWidth: .infinity, maxHeight: .infinity) // Center the modal
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
