import Foundation
import SwiftData

@Model
class BudgetHistory {
    var id: UUID = UUID()
    var amount: Double = 0.0
    var dateChanged: Date = Date.now
    
    init(amount: Double, dateChanged: Date = .now) {
        self.id = UUID()
        self.amount = amount
        self.dateChanged = dateChanged
    }
}

@Model
class Transaction {
    var id: UUID = UUID()
    var amount: Double = 0.0
    var categoryRawValue: String = SpendCategory.other.rawValue
    var note: String = ""
    var date: Date = Date.now
    var isExpense: Bool = true
    
    var paymentMethodRawValue: String = PaymentMethod.sbi.rawValue
    var contactName: String? = nil
    
    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }
    
    enum PaymentMethod: String, CaseIterable, Codable {
        case sbi = "SBI"
        case hdfc = "HDFC"
        case icici = "ICICI CC"
        case cash = "Cash"
    }

    init(amount: Double, category: SpendCategory, note: String, date: Date = .now, isExpense: Bool = true, paymentMethod: PaymentMethod = .sbi, contactName: String? = nil) {
        self.id = UUID()
        self.amount = amount
        self.categoryRawValue = category.rawValue
        self.note = note
        self.date = date
        self.isExpense = isExpense
        self.paymentMethodRawValue = paymentMethod.rawValue
        self.contactName = contactName
    }
}
