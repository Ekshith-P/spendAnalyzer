import SwiftUI
import SwiftData

struct BankIconView: View {
    let bankName: String
    
    var body: some View {
        let lower = bankName.lowercased()
        
        let imageName: String? = {
            if lower.contains("sbi") { return "sbi_logo" }
            if lower.contains("hdfc") { return "hdfc_logo" }
            if lower.contains("icici") || lower.contains("credit") { return "icici_logo" }
            if lower.contains("cash") { return "cash_logo" }
            return nil
        }()
        
        if let exactImage = imageName {
            Image(exactImage)
                .resizable()
                .scaledToFill()
                .frame(width: 18, height: 18)
                .clipShape(Circle())
        } else {
            let fallbackIcon = lower.contains("card") ? "creditcard.fill" : "building.columns.fill"
            let fallbackColor = Color.gray
            
            ZStack {
                Circle().fill(fallbackColor.opacity(0.15)).frame(width: 18, height: 18)
                Image(systemName: fallbackIcon)
                    .font(.system(size: 9))
                    .foregroundColor(fallbackColor)
            }
        }
    }
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    
    @State private var searchDate: Date = .now
    @State private var isFilteringByDate: Bool = false
    @State private var showingDatePicker = false
    
    var groupedTransactions: [(Date, [Transaction])] {
        var filtered = transactions
        
        if isFilteringByDate {
            let startOfSearch = Calendar.current.startOfDay(for: searchDate)
            filtered = transactions.filter { Calendar.current.startOfDay(for: $0.date) == startOfSearch }
        }
        
        let grouped = Dictionary(grouping: filtered) { tx in
            Calendar.current.startOfDay(for: tx.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_IN")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    func getIcon(for categoryName: String) -> String {
        return SpendCategory(rawValue: categoryName)?.icon ?? "📦"
    }
    
    func getShortBankName(for fullName: String) -> String {
        let lower = fullName.lowercased()
        if lower.contains("hdfc") { return "HDFC" }
        if lower.contains("sbi") { return "SBI" }
        if lower.contains("icici") || lower.contains("credit") { return "ICICI" }
        if lower.contains("cash") { return "Cash" }
        return fullName
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                if showingDatePicker {
                    VStack {
                        DatePicker("Select Date", selection: $searchDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(.orange)
                            .padding()
                            .onChange(of: searchDate) { _, _ in
                                isFilteringByDate = true
                                showingDatePicker = false
                            }
                        
                        if isFilteringByDate {
                            Button(action: {
                                isFilteringByDate = false
                                showingDatePicker = false
                            }) {
                                Text("Clear Filter").font(.headline).foregroundColor(.red).padding(.bottom, 15)
                            }
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .padding()
                }
                
                List {
                    if groupedTransactions.isEmpty {
                        Text(isFilteringByDate ? "No transactions on this date." : "No transactions yet.")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                            .padding(.top, 40)
                    } else {
                        ForEach(groupedTransactions, id: \.0) { date, dayTransactions in
                            Section(header: Text(date.formatted(date: .abbreviated, time: .omitted))
                                        .foregroundColor(.orange).fontWeight(.bold)) {
                                
                                ForEach(dayTransactions) { tx in
                                    HStack {
                                        Text(getIcon(for: tx.categoryRawValue))
                                            .font(.title2).frame(width: 45, height: 45)
                                            .background(Color(.systemGray6).opacity(0.5)).cornerRadius(12)
                                        
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(tx.categoryRawValue).font(.headline).foregroundColor(.white)
                                            
                                            HStack(spacing: 4) {
                                                BankIconView(bankName: tx.paymentMethodRawValue)
                                                Text(getShortBankName(for: tx.paymentMethodRawValue))
                                                
                                                if let contact = tx.contactName, !contact.isEmpty {
                                                    Text("•")
                                                    Image(systemName: "person.fill")
                                                    Text(contact).lineLimit(1)
                                                }
                                                
                                                Text("•")
                                                Text(tx.date.formatted(date: .omitted, time: .shortened))
                                            }
                                            .font(.caption).foregroundColor(.gray)
                                            
                                            // FIX: Adjusted for a non-optional String
                                            if !tx.note.isEmpty {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "pencil.line")
                                                    Text(tx.note)
                                                }
                                                .font(.caption2)
                                                .foregroundColor(.orange.opacity(0.8))
                                            }
                                        }
                                        Spacer()
                                        
                                        Text(tx.isExpense ? "-₹\(formatCurrency(tx.amount))" : "+₹\(formatCurrency(tx.amount))")
                                            .foregroundColor(tx.isExpense ? .white : .green)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(Color(.systemGray6).opacity(0.2))
                                }
                                .onDelete { indexSet in
                                    for index in indexSet { modelContext.delete(dayTransactions[index]) }
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("History")
            .preferredColorScheme(.dark)
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 15) {
                        if isFilteringByDate && !showingDatePicker {
                            Button(action: { isFilteringByDate = false }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                        Button(action: { withAnimation { showingDatePicker.toggle() } }) {
                            Image(systemName: isFilteringByDate ? "line.3.horizontal.decrease.circle.fill" : "calendar")
                                .font(.title3)
                                .foregroundColor(isFilteringByDate ? .orange : .gray)
                        }
                    }
                }
            }
        }
    }
}
