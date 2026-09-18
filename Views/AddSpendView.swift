import SwiftUI
import SwiftData
import ContactsUI

struct AddSpendView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var amountString: String = "0"
    @State private var note: String = ""
    @State private var showingNoteField = false
    @State private var isExpense: Bool = true
    @State private var selectedContact: String? = nil
    @State private var showingContactPicker = false
    
    @State private var selectedDate: Date = .now
    @State private var showDatePicker = false
    
    @State private var selectedCategory: String = "Select Category"
    @State private var selectedPayment: String = PaymentMethod.sbi.rawValue
    
    @FocusState private var isNoteFocused: Bool
    private var amount: Double { Double(amountString) ?? 0.0 }
    
    @AppStorage("customCategories") private var customCategoriesData: Data = Data()
    @AppStorage("customAccounts") private var customAccountsData: Data = Data()

    var allAccounts: [String] {
        var base = PaymentMethod.allCases.map { $0.rawValue }
        if let decoded = try? JSONDecoder().decode([String].self, from: customAccountsData) { base.append(contentsOf: decoded) }
        return base
    }
    
    var allCategories: [String] {
        var base = SpendCategory.allCases.filter { $0 != .income }.map { $0.rawValue }
        if let decoded = try? JSONDecoder().decode([String].self, from: customCategoriesData) { base.append(contentsOf: decoded) }
        return base
    }
    
    func getIcon(for categoryName: String) -> String {
        return SpendCategory(rawValue: categoryName)?.icon ?? "📦"
    }

    var formattedAmountDisplay: String {
        let parts = amountString.split(separator: ".")
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_IN")
        
        if parts.count == 2 {
            let whole = Double(parts[0]) ?? 0
            let decimal = parts[1]
            let formattedWhole = formatter.string(from: NSNumber(value: whole)) ?? "\(whole)"
            return "\(formattedWhole).\(decimal)"
        } else {
            let whole = Double(amountString) ?? 0
            let formattedWhole = formatter.string(from: NSNumber(value: whole)) ?? "\(whole)"
            return amountString.hasSuffix(".") ? "\(formattedWhole)." : formattedWhole
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            
            toggleSection.padding(.top, 10)
            
            HStack {
                Text("Date").foregroundColor(.gray).font(.subheadline)
                Spacer()
                Button(action: { showDatePicker = true }) {
                    Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .fontWeight(.semibold)
                        .foregroundColor(.orange) // NEW PALETTE
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.orange.opacity(0.15)) // NEW PALETTE
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
            
            if isExpense {
                accountPicker.padding(.top, 5)
            }
            
            VStack(spacing: 8) {
                Text("How much?").font(.subheadline).foregroundColor(.secondary)
                Text("₹ \(formattedAmountDisplay)").font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(isExpense ? .white : .green)
            }
            .padding(.top, 15)
            
            Spacer()
            
            if isExpense { categorySelector } else { incomeContactSelector }
            noteAndContactSection
            if !isNoteFocused { CustomNumPad(amountString: $amountString).padding(.horizontal, 10) } else { Spacer() }
            
            bottomButtons.padding(.bottom, 0)
        }
        .preferredColorScheme(.dark)
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showingContactPicker) { ContactPicker(contactName: $selectedContact) }
        .sheet(isPresented: $showDatePicker) {
            VStack {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.orange) // NEW PALETTE
                    .padding()
                    .onChange(of: selectedDate) { _, _ in
                        showDatePicker = false
                    }
            }
            .presentationDetents([.medium])
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - UI Components
    private var toggleSection: some View {
        HStack(spacing: 0) {
            Button(action: { isExpense = true }) {
                Text("Expense").font(.subheadline).fontWeight(isExpense ? .bold : .regular)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .background(isExpense ? Color(.systemGray5) : Color.clear)
                    .foregroundColor(isExpense ? .white : .gray).cornerRadius(10)
            }
            Button(action: { isExpense = false }) {
                Text("Income").font(.subheadline).fontWeight(!isExpense ? .bold : .regular)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .background(!isExpense ? Color(.systemGray5) : Color.clear)
                    .foregroundColor(!isExpense ? .white : .gray).cornerRadius(10)
            }
        }
        .background(Color(.systemGray6).opacity(0.3)).cornerRadius(10)
        .padding(.horizontal, 40)
    }
    
    private var accountPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(allAccounts, id: \.self) { method in
                    Button(action: { selectedPayment = method }) {
                        Text(method).font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(selectedPayment == method ? Color.orange.opacity(0.2) : Color.clear) // NEW PALETTE
                            .foregroundColor(selectedPayment == method ? .orange : .gray) // NEW PALETTE
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(selectedPayment == method ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1))
                            .cornerRadius(15)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var categorySelector: some View {
        Menu {
            ForEach(allCategories, id: \.self) { category in
                Button(action: {
                    selectedCategory = category
                    if category == SpendCategory.familyFriends.rawValue { showingContactPicker = true }
                }) {
                    Text("\(getIcon(for: category)) \(category)")
                }
            }
        } label: {
            HStack {
                if selectedCategory == "Select Category" {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Select Category").fontWeight(.semibold)
                } else {
                    Text(getIcon(for: selectedCategory))
                    Text(selectedCategory).fontWeight(.semibold)
                }
                Image(systemName: "chevron.up.chevron.down").font(.caption)
            }
            .foregroundColor(selectedCategory == "Select Category" ? .orange : .white) // NEW PALETTE
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color(.systemGray6).opacity(0.5)).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selectedCategory == "Select Category" ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1))
        }
    }
    
    private var incomeContactSelector: some View {
        Button(action: { showingContactPicker = true }) {
            HStack {
                Image(systemName: "person.crop.circle.badge.plus")
                Text(selectedContact == nil ? "From who? (Optional)" : "Received from: \(selectedContact!)")
            }
            .font(.subheadline).foregroundColor(.green)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color.green.opacity(0.15)).cornerRadius(20)
        }
    }
    
    private var noteAndContactSection: some View {
        HStack {
            if showingNoteField {
                TextField("Enter note...", text: $note)
                    .focused($isNoteFocused).submitLabel(.done)
                    .onSubmit { isNoteFocused = false }
                    .textFieldStyle(PlainTextFieldStyle()).foregroundColor(.white)
                    .padding(12).background(Color(.systemGray6).opacity(0.3)).cornerRadius(10)
            } else {
                Button(action: {
                    withAnimation { showingNoteField = true }; isNoteFocused = true
                }) { Text("+ add note").font(.callout).foregroundColor(.secondary) }
            }
            Spacer()
            if let contact = selectedContact, selectedCategory == SpendCategory.familyFriends.rawValue, isExpense {
                Text("To: \(contact)").font(.caption).foregroundColor(.orange).padding(.horizontal, 10).padding(.vertical, 6) // NEW PALETTE
                    .background(Color.orange.opacity(0.1)).cornerRadius(10)
            }
        }
        .padding(.horizontal).frame(height: 44)
    }
    
    private var bottomButtons: some View {
        HStack(spacing: 15) {
            Button(action: { dismiss() }) {
                Text("Cancel").font(.headline).frame(maxWidth: .infinity).padding()
                    .background(Color(.systemGray6))
                    .foregroundColor(.white).cornerRadius(15)
            }
            
            Button(action: saveTransaction) {
                Text("Save").font(.headline).frame(maxWidth: .infinity).padding()
                    .background(isSaveEnabled ? Color.orange : Color.orange.opacity(0.2)) // NEW PALETTE
                    .foregroundColor(isSaveEnabled ? .white : .gray).cornerRadius(15)
            }
            .disabled(!isSaveEnabled)
        }
        .padding(.horizontal)
    }
    
    private var isSaveEnabled: Bool {
        if amount <= 0 { return false }
        if isExpense && selectedCategory == "Select Category" { return false }
        return true
    }
    
    private func saveTransaction() {
        let transaction = Transaction(amount: amount, category: .other, note: note, date: selectedDate, isExpense: isExpense, paymentMethod: .sbi, contactName: selectedContact)
        transaction.categoryRawValue = isExpense ? selectedCategory : SpendCategory.income.rawValue
        transaction.paymentMethodRawValue = selectedPayment
        
        modelContext.insert(transaction)
        dismiss()
    }
}

// MARK: - Essential Subcomponents
struct ContactPicker: UIViewControllerRepresentable {
    // ... no changes needed here, just keep the standard implementation ...
    @Binding var contactName: String?
    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker
        init(_ parent: ContactPicker) { self.parent = parent }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.contactName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
}

struct CustomNumPad: View {
    // ... no changes needed here ...
    @Binding var amountString: String
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    let buttons = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "delete.left"]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(buttons, id: \.self) { button in
                Button(action: { buttonTapped(button) }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15).fill(Color(.systemGray6).opacity(0.2)).frame(height: 55)
                        if button == "delete.left" { Image(systemName: button).font(.title2).foregroundColor(.white)
                        } else { Text(button).font(.title).foregroundColor(.white) }
                    }
                }
            }
        }
    }
    private func buttonTapped(_ button: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if button == "delete.left" {
            if amountString.count > 1 { amountString.removeLast() } else { amountString = "0" }
        } else if button == "." {
            if !amountString.contains(".") { amountString += "." }
        } else {
            if amountString == "0" { amountString = button } else { amountString += button }
        }
    }
}
