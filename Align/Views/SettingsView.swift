import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var dailyReminder = true
    @State private var soundEffects = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Align Title and X button vertically based on their text baseline
            HStack(alignment: .firstTextBaseline) {
                Text("Settings")
                    .font(.futura(size: 32, weight: .bold))
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.title2) // The size/font of the icon affects baseline alignment
                        .foregroundColor(themeManager.accentColor) // Use accent color
                }
            }
            .padding() // Padding affects final position
            // Removed background modifier to inherit the parent's gray background

            ScrollView {
                VStack(spacing: 24) {
                    // Appearance Section
                    SettingsSectionView(
                        icon: "paintpalette",
                        title: "Appearance"
                    ) {
                        // Mode
                        SettingsOptionView(title: "Mode") {
                            SegmentedPickerView(
                                options: ThemeManager.AppTheme.allCases.map { $0.rawValue.capitalized },
                                selectedIndex: Binding(
                                    get: { ThemeManager.AppTheme.allCases.firstIndex(of: themeManager.theme) ?? 0 },
                                    set: { themeManager.theme = ThemeManager.AppTheme.allCases[$0] }
                                )
                            )
                        }
                        
                        // Font Size
                        SettingsOptionView(title: "Font Size") {
                            SegmentedPickerView(
                                options: ThemeManager.FontSize.allCases.map { $0.rawValue.capitalized },
                                selectedIndex: Binding(
                                    get: { ThemeManager.FontSize.allCases.firstIndex(of: themeManager.fontSize) ?? 0 },
                                    set: { themeManager.fontSize = ThemeManager.FontSize.allCases[$0] }
                                )
                            )
                        }
                        
                        // Accent Color
                        SettingsOptionView(title: "Accent Color") {
                            HStack(spacing: 12) {
                                ForEach(themeManager.accentColors.indices, id: \.self) { index in
                                    let color = themeManager.accentColors[index]
                                    Circle()
                                        .fill(color)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: themeManager.accentColor == color ? 2 : 0)
                                        )
                                        .onTapGesture {
                                            themeManager.accentColor = color
                                        }
                                }
                            }
                        }
                    }
                    
                    // Notifications Section
                    SettingsSectionView(
                        icon: "bell",
                        title: "Notifications"
                    ) {
                        // Daily Reminder
                        SettingsOptionView(
                            title: "Daily Reminder",
                            subtitle: "Receive a reminder to journal each day"
                        ) {
                            Toggle("", isOn: $dailyReminder)
                                .toggleStyle(SwitchToggleStyle(tint: themeManager.accentColor))
                        }
                        
                        // Sound Effects
                        SettingsOptionView(
                            title: "Sound Effects",
                            subtitle: "Play subtle sounds during interactions"
                        ) {
                            Toggle("", isOn: $soundEffects)
                                .toggleStyle(SwitchToggleStyle(tint: themeManager.accentColor))
                        }
                    }
                    
                    // About Section
                    SettingsSectionView(
                        icon: "info.circle",
                        title: "About"
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Personal Feedback Cycle v1.0")
                                .font(.futura(size: 16))
                            
                            Text("This app helps you sustain the Energy → Focus → Work → Income → Liquidity → Home → Mental → Energy loop with minimal daily interaction.")
                                .font(.futura(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding()
            }
        }
        // Restore background here so the view itself controls its appearance
        .background(Color(UIColor.systemGray6))
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct SettingsSectionView<Content: View>: View {
    let icon: String
    let title: String
    let content: Content
    
    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.futura(size: 24, weight: .bold))
            }
            
            content
                .padding(.leading, 4)
        }
    }
}

struct SettingsOptionView<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let content: Content
    
    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.futura(size: 18))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.futura(size: 14))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            content
        }
        .padding(.vertical, 8)
    }
}

struct SegmentedPickerView: View {
    let options: [String]
    @Binding var selectedIndex: Int
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: {
                    selectedIndex = index
                }) {
                    Text(options[index])
                        .font(.futura(size: 16))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(selectedIndex == index ? themeManager.accentColor : Color.clear)
                        .foregroundColor(selectedIndex == index ? .white : .gray)
                        .cornerRadius(16)
                }
            }
        }
        .background(Color(UIColor.systemGray5))
        .cornerRadius(16)
    }
}