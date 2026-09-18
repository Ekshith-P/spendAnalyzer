import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allTransactions: [Transaction]
    @Query(sort: \BudgetHistory.dateChanged, order: .reverse) private var budgetLogs: [BudgetHistory]
    
    @AppStorage("monthlyBudgetLimit") private var monthlyBudgetLimit: Double = 10000.0
    @AppStorage("customCategories") private var customCategoriesData: Data = Data()
    @AppStorage("customAccounts") private var customAccountsData: Data = Data()
    
    @State private var showingPinPrompt = false
    @State private var pinInput = ""
    @State private var failedAttempts = 0
    @State private var showErrorMessage = false
    
    @State private var pendingAction: (() -> Void)? = nil
    @State private var initialBudgetAtOpen: Double = 0.0
    
    @State private var showingNewAccountAlert = false
    @State private var showingNewCategoryAlert = false
    @State private var newItemName = ""
    
    var customAccounts: [String] {
        if let decoded = try? JSONDecoder().decode([String].self, from: customAccountsData) { return decoded }
        return []
    }
    
    var customCategories: [String] {
        if let decoded = try? JSONDecoder().decode([String].self, from: customCategoriesData) { return decoded }
        return []
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Budget Options")) {
                    HStack {
                        Text("Monthly Limit")
                        Spacer()
                        TextField("Amount", value: $monthlyBudgetLimit, format: .currency(code: "INR"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Custom Accounts")) {
                    ForEach(customAccounts, id: \.self) { account in
                        HStack {
                            Text(account)
                            Spacer()
                            // Explicit visible trash button
                            Button(action: {
                                pendingAction = {
                                    var current = customAccounts
                                    current.removeAll { $0 == account }
                                    if let encoded = try? JSONEncoder().encode(current) { customAccountsData = encoded }
                                }
                                showingPinPrompt = true
                            }) {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                        }
                    }
                    Button("Add Custom Bank/Account") { showingNewAccountAlert = true }.foregroundColor(.cyan)
                }
                
                Section(header: Text("Custom Categories")) {
                    ForEach(customCategories, id: \.self) { category in
                        HStack {
                            Text(category)
                            Spacer()
                            // Explicit visible trash button
                            Button(action: {
                                pendingAction = {
                                    var current = customCategories
                                    current.removeAll { $0 == category }
                                    if let encoded = try? JSONEncoder().encode(current) { customCategoriesData = encoded }
                                }
                                showingPinPrompt = true
                            }) {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                        }
                    }
                    Button("Add Custom Category") { showingNewCategoryAlert = true }.foregroundColor(.cyan)
                }
                
                Section(header: Text("Budget History")) {
                    if budgetLogs.isEmpty {
                        Text("No budget changes recorded yet.").foregroundColor(.gray).font(.caption)
                    } else {
                        ForEach(budgetLogs) { log in
                            HStack {
                                Text(log.dateChanged.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundColor(.gray)
                                Spacer()
                                Text("₹\(String(format: "%.0f", log.amount))")
                                    .foregroundColor(.white)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet { modelContext.delete(budgetLogs[index]) }
                        }
                    }
                }
                
                Section(header: Text("Data Export")) {
                    if let csvURL = CSVExporter.generateCSVURL(from: allTransactions) {
                        ShareLink(item: csvURL) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export as CSV")
                            }
                            .foregroundColor(.cyan)
                        }
                    } else {
                        Text("Export unavailable").foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("Data Management"), footer: Text("This will permanently delete all expenses and income. Cannot be undone.")) {
                    Button(role: .destructive, action: {
                        pendingAction = nil
                        showingPinPrompt = true
                    }) {
                        Text("Reset Budget & All Spends").foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if monthlyBudgetLimit != initialBudgetAtOpen {
                            let newLog = BudgetHistory(amount: monthlyBudgetLimit)
                            modelContext.insert(newLog)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear { initialBudgetAtOpen = monthlyBudgetLimit }
            
            .alert("New Account", isPresented: $showingNewAccountAlert) {
                TextField("e.g. Axis Bank", text: $newItemName)
                Button("Add") {
                    let name = newItemName
                    pendingAction = { saveCustomAccount(name) }
                    showingPinPrompt = true
                }
                Button("Cancel", role: .cancel) { newItemName = "" }
            }
            .alert("New Category", isPresented: $showingNewCategoryAlert) {
                TextField("e.g. Pets", text: $newItemName)
                Button("Add") {
                    let name = newItemName
                    pendingAction = { saveCustomCategory(name) }
                    showingPinPrompt = true
                }
                Button("Cancel", role: .cancel) { newItemName = "" }
            }
            
            .sheet(isPresented: $showingPinPrompt) {
                PinPromptView(pinInput: $pinInput, showErrorMessage: $showErrorMessage, onSubmit: handlePinSubmit, onCancel: { showingPinPrompt = false })
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveCustomAccount(_ name: String) {
        guard !name.isEmpty else { return }
        var current = customAccounts
        if !current.contains(name) {
            current.append(name)
            if let encoded = try? JSONEncoder().encode(current) { customAccountsData = encoded }
        }
        newItemName = ""
    }
    
    private func saveCustomCategory(_ name: String) {
        guard !name.isEmpty else { return }
        var current = customCategories
        if !current.contains(name) {
            current.append(name)
            if let encoded = try? JSONEncoder().encode(current) { customCategoriesData = encoded }
        }
        newItemName = ""
    }
    
    private func handlePinSubmit() {
        if pinInput == "0495" {
            if let action = pendingAction {
                action()
                pendingAction = nil
            } else {
                for transaction in allTransactions { modelContext.delete(transaction) }
                for log in budgetLogs { modelContext.delete(log) }
            }
            
            showingPinPrompt = false; pinInput = ""; failedAttempts = 0; showErrorMessage = false
        } else {
            failedAttempts += 1; pinInput = ""; showErrorMessage = true
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            if failedAttempts >= 2 {
                @AppStorage("isAppLocked") var isAppLocked = false
                isAppLocked = true
                exit(0)
            }
        }
    }
}

// MARK: - Custom PIN Prompt Subview
struct PinPromptView: View {
    @Binding var pinInput: String
    @Binding var showErrorMessage: Bool
    var onSubmit: () -> Void
    var onCancel: () -> Void
    
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50)).foregroundColor(.red).padding(.top, 40)
                Text("Enter Security PIN").font(.title2).fontWeight(.bold).foregroundColor(.white)
                Text("Verify your identity to proceed.")
                    .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal)
                SecureField("4-Digit PIN", text: $pinInput).keyboardType(.numberPad).focused($isInputFocused)
                    .padding().background(Color(.systemGray6).opacity(0.3)).cornerRadius(10).foregroundColor(.white)
                    .padding(.horizontal, 40).padding(.top, 20)
                if showErrorMessage { Text("Incorrect PIN.").foregroundColor(.red).font(.callout) }
                Button(action: onSubmit) {
                    Text("Confirm").font(.headline).frame(maxWidth: .infinity).padding()
                        .background(pinInput.count > 0 ? Color.cyan : Color.cyan.opacity(0.3)).foregroundColor(.white).cornerRadius(15)
                }
                .disabled(pinInput.isEmpty).padding(.horizontal, 40).padding(.top, 10)
                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel).foregroundColor(.white)
                }
            }
            .onAppear { isInputFocused = true }
        }
        .preferredColorScheme(.dark)
    }
}
