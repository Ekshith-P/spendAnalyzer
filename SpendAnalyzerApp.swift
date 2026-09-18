import SwiftUI
import SwiftData
import AppIntents

@main
struct SpendAnalyzerApp: App {
    init() {
        SpendAnalyzerShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        // Safely injects BOTH models into the database
        .modelContainer(for: [Transaction.self, BudgetHistory.self])
    }
}
