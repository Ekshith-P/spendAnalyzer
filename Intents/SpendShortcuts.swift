import AppIntents
import SwiftUI

struct LogSpendIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Transaction"
    static var description: IntentDescription = IntentDescription("Quickly open Spend Analyzer.")
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // NEW: Writes a flag to the hard drive so the UI catches it instantly upon load
        UserDefaults.standard.set(true, forKey: "triggerQuickAdd")
        return .result()
    }
}

struct SpendAnalyzerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogSpendIntent(),
            phrases: ["Log an expense in \(.applicationName)"],
            shortTitle: "Add Spend",
            systemImageName: "indianrupeesign"
        )
    }
}
