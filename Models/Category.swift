import Foundation
import SwiftUI

enum PaymentMethod: String, CaseIterable, Codable {
    case sbi = "SBI"
    case hdfc = "HDFC"
    case creditCard = "Icici CC"
    case cash = "Cash"
}

enum SpendCategory: String, CaseIterable, Codable {
    case food = "Food"
    case transport = "Transport"
    case shopping = "Shopping"
    case bills = "Bills"
    case entertainment = "Entertainment"
    case health = "Health"
    case personal = "Personal"
    case gym = "Gym"
    case familyFriends = "Family/Friends"
    case investments = "Investments"
    case drinks = "Drinks"
    case other = "Other"
    case income = "Added Money"

    var icon: String {
        switch self {
        case .food: return "🍔"
        case .transport: return "🚗"
        case .shopping: return "🛍️"
        case .bills: return "📄"
        case .entertainment: return "🎬"
        case .health: return "⚕️"
        case .personal: return "💆‍♂️"
        case .gym: return "🏋️‍♂️"
        case .familyFriends: return "🤝"
        case .investments: return "📈"
        case .drinks: return "🍻"
        case .other: return "📦"
        case .income: return "💰"
        }
    }
}
