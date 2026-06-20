import Foundation
import SwiftData

@Model
final class CustomStatus {
    var name: String = ""
    var colorHex: String = "#888888"
    var order: Int = 0

    init(name: String = "", colorHex: String = "#888888", order: Int = 0) {
        self.name = name
        self.colorHex = colorHex
        self.order = order
    }
}
