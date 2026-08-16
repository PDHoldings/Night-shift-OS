import Foundation

#if canImport(UIKit)
import UIKit

/// Phase 2 (§7.3): photo → calorie estimation behind a protocol so vendors
/// are swappable (Passio SDK first; fallback Claude vision via Workers proxy).
/// Phase 1 ships only the abstraction — do not implement estimation here.
protocol FoodRecognitionProvider: Sendable {
    func estimate(image: UIImage) async throws -> [FoodEstimate]
}

struct FoodEstimate: Sendable, Equatable {
    let name: String
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    /// 0...1 — always shown to the user; estimates are never auto-logged
    /// without confirmation.
    let confidence: Double
}
#endif
