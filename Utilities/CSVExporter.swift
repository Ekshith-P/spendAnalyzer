import Foundation
import CoreTransferable

class CSVExporter {
    // We now return a physical file URL instead of raw text
    static func generateCSVURL(from transactions: [Transaction]) -> URL? {
        var csvText = "Date,Type,Category,Amount,Note\n"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        
        for tx in transactions {
            let dateStr = formatter.string(from: tx.date)
            let typeStr = tx.isExpense ? "Expense" : "Income"
            let catStr = tx.category.rawValue
            let noteStr = "\"\(tx.note)\""
            
            let row = "\(dateStr),\(typeStr),\(catStr),\(tx.amount),\(noteStr)\n"
            csvText.append(row)
        }
        
        // Write to a temporary file with an explicit .csv extension
        let fileName = "SpendAnalyzer_History.csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvText.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to create CSV file: \(error)")
            return nil
        }
    }
}
