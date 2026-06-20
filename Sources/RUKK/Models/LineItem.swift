import Foundation
import SwiftData

@Model
final class LineItem {
    var itemDescription: String = ""
    var quantity: Decimal = 1
    var unitPrice: Decimal = 0             // verð án VSK
    var taxRate: Decimal = 24              // VSK% fyrir þessa línu
    var order: Int = 0

    var invoice: Invoice?

    var subtotal: Decimal { quantity * unitPrice }                          // án VSK
    var taxAmount: Decimal { subtotal * taxRate / 100 }
    var subtotalIncTax: Decimal { subtotal + taxAmount }                    // með VSK
    var unitPriceIncTax: Decimal { unitPrice + unitPrice * taxRate / 100 }

    init(description: String = "", quantity: Decimal = 1, unitPrice: Decimal = 0,
         taxRate: Decimal = 24, order: Int = 0) {
        self.itemDescription = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.taxRate = taxRate
        self.order = order
    }
}
