import SwiftUI
import SwiftData
import Charts

// MARK: - Data Models
struct ContactSummary: Identifiable {
    let id = UUID()
    let name: String
    var sent: Double
    var received: Double
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let category: String
    let amount: Double
}

struct AnalyticsView: View {
    @Query private var transactions: [Transaction]
    @AppStorage("monthlyBudgetLimit") private var monthlyBudgetLimit: Double = 10000.0
    @AppStorage("customAccounts") private var customAccountsData: Data = Data()
    
    @State private var selectedTimeFilter = "Days"
    let timeFilters = ["Days", "Weeks", "Months", "Years"]
    @State private var selectedBank = "All Accounts"
    
    // Interactive States
    @State private var showingSettings = false
    @State private var selectedContactForDetails: String? = nil
    @State private var selectedCategoryForDetails: String? = nil
    @State private var rawSelectedDate: Date? = nil
    @State private var chartScrollPosition: Date = Date()
    
    // MARK: - Filters
    var bankFilters: [String] {
        var base = ["All Accounts", "SBI Account", "HDFC Bank", "ICICI CC", "Cash"]
        if let decoded = try? JSONDecoder().decode([String].self, from: customAccountsData) { base.append(contentsOf: decoded) }
        return base
    }
    
    var bankFilteredTransactions: [Transaction] {
        if selectedBank == "All Accounts" { return transactions.filter { $0.isExpense } }
        return transactions.filter { tx in
            guard tx.isExpense else { return false }
            let method = tx.paymentMethodRawValue.lowercased()
            let target = selectedBank.lowercased()
            
            if target == "icici cc" { return method.contains("icici") || method.contains("credit") || method == "icici cc" }
            if target == "sbi account" { return method.contains("sbi") || method == "sbi account" }
            if target == "hdfc bank" { return method.contains("hdfc") || method == "hdfc bank" }
            if target == "cash" { return method.contains("cash") }
            return method == target
        }
    }
    
    var dateFilteredTransactions: [Transaction] {
        var valid = bankFilteredTransactions
        if let tappedDate = rawSelectedDate {
            let calendar = Calendar.current
            valid = valid.filter { tx in
                let keyDate: Date
                switch selectedTimeFilter {
                case "Days": keyDate = calendar.startOfDay(for: tx.date)
                case "Weeks": keyDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: tx.date)) ?? tx.date
                case "Months": keyDate = calendar.date(from: calendar.dateComponents([.year, .month], from: tx.date)) ?? tx.date
                case "Years": keyDate = calendar.date(from: calendar.dateComponents([.year], from: tx.date)) ?? tx.date
                default: keyDate = calendar.startOfDay(for: tx.date)
                }
                return keyDate == tappedDate
            }
        }
        return valid
    }
    
    func formatCurrency(_ amount: Double, showDecimals: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_IN")
        formatter.minimumFractionDigits = showDecimals ? 2 : 0
        formatter.maximumFractionDigits = showDecimals ? 2 : 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    // MARK: - Global Color Logic
    var globalCategoryColors: [String: Color] {
        var totals: [String: Double] = [:]
        for tx in bankFilteredTransactions { totals[tx.categoryRawValue, default: 0] += tx.amount }
        let sortedCategories = totals.sorted { $0.value > $1.value }.map { $0.key }
        
        let screenTimePalette: [Color] = [.blue, .cyan, .gray.opacity(0.7), .orange, .purple, .green]
        var colorMap: [String: Color] = [:]
        
        for (index, cat) in sortedCategories.enumerated() {
            colorMap[cat] = screenTimePalette[index % screenTimePalette.count]
        }
        return colorMap
    }
    
    var chartDomain: [String] { globalCategoryColors.keys.sorted() }
    var chartRange: [Color] { chartDomain.compactMap { globalCategoryColors[$0] } }
    
    // Calculates totals dynamically for the list at the bottom based on tap
    var dynamicCategoryTotals: [(categoryName: String, icon: String, amount: Double)] {
        var totals: [String: Double] = [:]
        for tx in dateFilteredTransactions { totals[tx.categoryRawValue, default: 0] += tx.amount }
        return totals.map {
            let icon = SpendCategory(rawValue: $0.key)?.icon ?? "📦"
            return (categoryName: $0.key, icon: icon, amount: $0.value)
        }.sorted { $0.amount > $1.amount }
    }
    
    var maxCategoryAmount: Double { dynamicCategoryTotals.first?.amount ?? 1.0 }
    
    // MARK: - Chart Engine
    var chartData: [ChartDataPoint] {
        var grouped: [Date: [String: Double]] = [:]
        let calendar = Calendar.current
        
        for tx in bankFilteredTransactions {
            let keyDate: Date
            switch selectedTimeFilter {
            case "Days": keyDate = calendar.startOfDay(for: tx.date)
            case "Weeks": keyDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: tx.date)) ?? tx.date
            case "Months": keyDate = calendar.date(from: calendar.dateComponents([.year, .month], from: tx.date)) ?? tx.date
            case "Years": keyDate = calendar.date(from: calendar.dateComponents([.year], from: tx.date)) ?? tx.date
            default: keyDate = calendar.startOfDay(for: tx.date)
            }
            grouped[keyDate, default: [:]][tx.categoryRawValue, default: 0] += tx.amount
        }
        
        var result: [ChartDataPoint] = []
        for (date, categories) in grouped {
            for (category, amount) in categories {
                result.append(ChartDataPoint(date: date, category: category, amount: amount))
            }
        }
        return result.sorted { $0.date < $1.date }
    }
    
    var chartUnit: Calendar.Component {
        switch selectedTimeFilter {
        case "Days": return .day
        case "Weeks": return .weekOfYear
        case "Months": return .month
        case "Years": return .year
        default: return .day
        }
    }
    
    var visibleDomain: TimeInterval {
        let day: TimeInterval = 86400
        switch selectedTimeFilter {
        case "Days": return day * 7
        case "Weeks": return day * 7 * 5
        case "Months": return day * 30 * 6
        case "Years": return day * 365 * 4
        default: return day * 7
        }
    }
    
    var averageDailySpend: Double {
        var dailyTotals: [Date: Double] = [:]
        for item in chartData { dailyTotals[item.date, default: 0] += item.amount }
        guard !dailyTotals.isEmpty else { return 0 }
        return dailyTotals.values.reduce(0, +) / Double(dailyTotals.count)
    }

    var contactSummaries: [ContactSummary] {
        var dict: [String: ContactSummary] = [:]
        for tx in transactions {
            if let name = tx.contactName, !name.isEmpty {
                if dict[name] == nil { dict[name] = ContactSummary(name: name, sent: 0, received: 0) }
                if tx.isExpense { dict[name]?.sent += tx.amount }
                else { dict[name]?.received += tx.amount }
            }
        }
        return Array(dict.values).sorted { ($0.sent + $0.received) > ($1.sent + $1.received) }
    }

    // MARK: - Main Body
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    topFilterSection
                    chartCardSection
                    categoriesSection
                    peopleSection
                    Spacer().frame(height: 40)
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill").font(.headline).foregroundColor(.gray)
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: Binding(
                get: { selectedContactForDetails != nil },
                set: { if !$0 { selectedContactForDetails = nil } }
            )) {
                if let contact = selectedContactForDetails {
                    ContactDetailSheet(contactName: contact, transactions: transactions)
                        .presentationDetents([.large])
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedCategoryForDetails != nil },
                set: { if !$0 { selectedCategoryForDetails = nil } }
            )) {
                if let category = selectedCategoryForDetails {
                    CategoryDetailSheet(categoryName: category, transactions: dateFilteredTransactions)
                        .presentationDetents([.large])
                }
            }
        }
    }
    
    // MARK: - Subviews
    private var topFilterSection: some View {
        VStack(spacing: 15) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(bankFilters, id: \.self) { bank in
                        Button(action: {
                            selectedBank = bank
                            rawSelectedDate = nil
                        }) {
                            Text(bank).font(.subheadline).fontWeight(selectedBank == bank ? .bold : .medium)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(selectedBank == bank ? Color(.systemGray4) : Color.clear)
                                .foregroundColor(selectedBank == bank ? .white : .gray)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 5)
            
            Picker("Time", selection: $selectedTimeFilter) {
                ForEach(timeFilters, id: \.self) { filter in Text(filter) }
            }
            .pickerStyle(.segmented).padding(.horizontal)
            .onChange(of: selectedTimeFilter) { _, _ in
                rawSelectedDate = nil
                if let last = chartData.last?.date { chartScrollPosition = last }
            }
        }
    }
    
    private var chartCardSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                
                // Left Side: Spend amounts
                VStack(alignment: .leading, spacing: 4) {
                    if let selectedDate = rawSelectedDate {
                        Text(selectedDate, format: selectedTimeFilter == "Days" ? .dateTime.weekday(.wide).month().day() : .dateTime.month().year())
                            .font(.subheadline).foregroundColor(.gray)
                        let selectedAmount = dateFilteredTransactions.reduce(0) { $0 + $1.amount }
                        Text("₹\(formatCurrency(selectedAmount))")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Text("Average Spend").font(.subheadline).foregroundColor(.gray)
                        HStack(alignment: .lastTextBaseline) {
                            Text("₹\(formatCurrency(averageDailySpend))")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("/ \(selectedTimeFilter.dropLast().lowercased())").font(.headline).foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                
                // Right Side: Budget Left & Close Button
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .trailing, spacing: 4) {
                        let totalSpent = bankFilteredTransactions.reduce(0) { $0 + $1.amount }
                        let budgetLeft = monthlyBudgetLimit - totalSpent
                        
                        Text("Budget Left").font(.caption).foregroundColor(.gray)
                        Text(budgetLeft < 0 ? "Over Budget" : "₹\(formatCurrency(budgetLeft))")
                            .font(.subheadline).fontWeight(.bold).foregroundColor(budgetLeft < 0 ? .red : .green)
                        Text("of ₹\(formatCurrency(monthlyBudgetLimit))").font(.caption2).foregroundColor(.gray)
                    }
                    .padding(10)
                    .background(Color(.systemGray5).opacity(0.3))
                    .cornerRadius(12)
                    
                    if rawSelectedDate != nil {
                        Button(action: { rawSelectedDate = nil }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray).font(.title2)
                        }
                    }
                }
            }
            .contentShape(Rectangle()) // Keeps tap area clean
            
            if chartData.isEmpty {
                Text("No data available.")
                    .foregroundColor(.gray).frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart {
                    ForEach(chartData) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: chartUnit),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(by: .value("Category", item.category))
                        .opacity((rawSelectedDate == nil || rawSelectedDate == item.date) ? 1.0 : 0.3)
                        .cornerRadius(2)
                    }
                    
                    RuleMark(y: .value("Average", averageDailySpend))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .foregroundStyle(Color.green)
                        .annotation(position: .trailing, alignment: .center) {
                            Text("avg").font(.caption2).foregroundColor(.green).padding(.leading, 2)
                        }
                }
                .chartForegroundStyleScale(domain: chartDomain, range: chartRange)
                .chartLegend(.hidden)
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: visibleDomain)
                .chartScrollPosition(x: $chartScrollPosition)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(Color.gray.opacity(0.4))
                        AxisValueLabel {
                            let intValue = value.as(Int.self) ?? 0
                            let labelText = intValue >= 1000 ? "\(intValue/1000)k" : "\(intValue)"
                            Text(labelText).font(.caption2).foregroundColor(.gray)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: chartUnit)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: selectedTimeFilter == "Days" ? .dateTime.weekday(.narrow) : .dateTime.day().month(.narrow))
                                    .font(.caption2).foregroundColor(.gray)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { location in
                                let xPosition = location.x - geometry[proxy.plotAreaFrame].origin.x
                                guard xPosition >= 0 else { return }
                                if let tappedDate = proxy.value(atX: xPosition, as: Date.self) {
                                    if let closest = chartData.min(by: { abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate)) }) {
                                        rawSelectedDate = (rawSelectedDate == closest.date) ? nil : closest.date
                                    }
                                }
                            }
                    }
                }
                .frame(height: 180)
                .padding(.vertical, 10)
                .onAppear {
                    if let lastDate = chartData.last?.date { chartScrollPosition = lastDate }
                }
            }
            
            Divider().background(Color.gray.opacity(0.5))
            
            HStack(alignment: .top, spacing: 20) {
                ForEach(dynamicCategoryTotals.prefix(3), id: \.categoryName) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.categoryName)
                            .font(.caption)
                            .foregroundColor(globalCategoryColors[item.categoryName] ?? .gray)
                            .lineLimit(1)
                        Text("₹\(formatCurrency(item.amount))")
                            .font(.caption2).fontWeight(.semibold).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Divider().background(Color.gray.opacity(0.5))
            
            HStack {
                Text(rawSelectedDate == nil ? "Total Spend" : "Selected Total")
                    .font(.subheadline).foregroundColor(.white)
                Spacer()
                let displayTotal = rawSelectedDate == nil ? bankFilteredTransactions.reduce(0) { $0 + $1.amount } : dateFilteredTransactions.reduce(0) { $0 + $1.amount }
                Text("₹\(formatCurrency(displayTotal))")
                    .font(.subheadline).foregroundColor(.gray)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(24)
        .padding(.horizontal)
    }

    private var categoriesSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text(rawSelectedDate == nil ? "Most Used" : "Selected Categories")
                    .font(.title3).fontWeight(.bold).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal).padding(.top, 10).padding(.bottom, 10)
            
            if dynamicCategoryTotals.isEmpty {
                Text("No expenses found.").foregroundColor(.gray).padding(.bottom, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(dynamicCategoryTotals, id: \.categoryName) { item in
                        let barColor = globalCategoryColors[item.categoryName] ?? .gray
                        
                        Button(action: { selectedCategoryForDetails = item.categoryName }) {
                            HStack(spacing: 15) {
                                Text(item.icon).font(.title2).frame(width: 45, height: 45)
                                    .background(Color(.systemGray6).opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(item.categoryName).font(.subheadline).foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray)
                                    }
                                    
                                    HStack {
                                        GeometryReader { geometry in
                                            let ratio = CGFloat(item.amount / maxCategoryAmount)
                                            let barWidth = max(0, geometry.size.width * ratio)
                                            
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray6).opacity(0.3)).frame(height: 6)
                                                RoundedRectangle(cornerRadius: 4).fill(barColor)
                                                    .frame(width: barWidth, height: 6)
                                            }
                                        }.frame(height: 6)
                                        
                                        Text("₹\(formatCurrency(item.amount))")
                                            .font(.caption2).foregroundColor(.gray)
                                            .frame(width: 60, alignment: .trailing)
                                    }
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                        }
                        
                        if item.categoryName != dynamicCategoryTotals.last?.categoryName {
                            Divider().background(Color.gray.opacity(0.3)).padding(.leading, 75)
                        }
                    }
                }
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(20)
                .padding(.horizontal)
            }
        }
    }
    
    private var peopleSection: some View {
        VStack(spacing: 0) {
            if !contactSummaries.isEmpty && rawSelectedDate == nil {
                HStack {
                    Text("People").font(.title3).fontWeight(.bold).foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal).padding(.top, 20).padding(.bottom, 10)
                
                VStack(spacing: 0) {
                    ForEach(contactSummaries) { contact in
                        
                        Button(action: { selectedContactForDetails = contact.name }) {
                            HStack {
                                Image(systemName: "person.circle.fill").font(.largeTitle).foregroundColor(.gray)
                                Text(contact.name).font(.subheadline).foregroundColor(.white)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    if contact.sent > 0 { Text("Sent: ₹\(formatCurrency(contact.sent))").font(.caption2).foregroundColor(.gray) }
                                    if contact.received > 0 { Text("Received: ₹\(formatCurrency(contact.received))").font(.caption2).foregroundColor(.green) }
                                }
                                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray).padding(.leading, 5)
                            }
                            .padding(.vertical, 12).padding(.horizontal)
                        }
                        
                        if contact.id != contactSummaries.last?.id {
                            Divider().background(Color.gray.opacity(0.3)).padding(.leading, 70)
                        }
                    }
                }
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(20)
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Category Drill Down Sheet
struct CategoryDetailSheet: View {
    let categoryName: String
    let transactions: [Transaction]
    @Environment(\.dismiss) private var dismiss
    
    var categoryTransactions: [Transaction] {
        transactions.filter { $0.categoryRawValue == categoryName }.sorted { $0.date > $1.date }
    }
    
    var totalAmount: Double { categoryTransactions.reduce(0) { $0 + $1.amount } }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_IN")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Spent").font(.caption).foregroundColor(.gray)
                    Text("₹\(formatCurrency(totalAmount))").font(.title).fontWeight(.bold).foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6).opacity(0.4))
                .cornerRadius(15)
                .padding()
                
                List {
                    ForEach(categoryTransactions) { tx in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(tx.paymentMethodRawValue).font(.headline).foregroundColor(.white)
                                HStack(spacing: 6) {
                                    Text(tx.date.formatted(date: .abbreviated, time: .shortened))
                                }
                                .font(.caption).foregroundColor(.gray)
                                
                                if !tx.note.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil.line")
                                        Text(tx.note)
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.blue.opacity(0.8))
                                }
                            }
                            Spacer()
                            Text("-₹\(formatCurrency(tx.amount))")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color(.systemGray6).opacity(0.2))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Contact Drill Down Sheet
struct ContactDetailSheet: View {
    let contactName: String
    let transactions: [Transaction]
    @Environment(\.dismiss) private var dismiss
    
    var contactTransactions: [Transaction] {
        transactions.filter { $0.contactName == contactName }.sorted { $0.date > $1.date }
    }
    var totalSent: Double { contactTransactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount } }
    var totalReceived: Double { contactTransactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_IN")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Total Sent").font(.caption).foregroundColor(.gray)
                        Text("₹\(formatCurrency(totalSent))").font(.title2).fontWeight(.bold).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding().background(Color(.systemGray6).opacity(0.4)).cornerRadius(15)
                    
                    VStack(alignment: .leading) {
                        Text("Total Received").font(.caption).foregroundColor(.gray)
                        Text("₹\(formatCurrency(totalReceived))").font(.title2).fontWeight(.bold).foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding().background(Color(.systemGray6).opacity(0.4)).cornerRadius(15)
                }
                .padding()
                
                List {
                    ForEach(contactTransactions) { tx in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(tx.categoryRawValue).font(.headline).foregroundColor(.white)
                                HStack(spacing: 6) {
                                    Image(systemName: tx.isExpense ? "arrow.up.right" : "arrow.down.left")
                                        .foregroundColor(tx.isExpense ? .gray : .green)
                                    Text(tx.paymentMethodRawValue)
                                    Text("•")
                                    Text(tx.date.formatted(date: .abbreviated, time: .shortened))
                                }
                                .font(.caption).foregroundColor(.gray)
                                
                                if !tx.note.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil.line")
                                        Text(tx.note)
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.blue.opacity(0.8))
                                }
                            }
                            Spacer()
                            Text(tx.isExpense ? "-₹\(formatCurrency(tx.amount))" : "+₹\(formatCurrency(tx.amount))")
                                .fontWeight(.bold)
                                .foregroundColor(tx.isExpense ? .white : .green)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color(.systemGray6).opacity(0.2))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(contactName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
