import Foundation

/// Swappable food-database vendor (§7.3). Open Food Facts first.
protocol FoodDatabaseProvider: Sendable {
    func searchBarcode(_ barcode: String) async throws -> FoodItem?
    func searchText(_ query: String) async throws -> [FoodItem]
}

struct FoodItem: Sendable, Equatable {
    let name: String
    let brand: String?
    let kcalPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let barcode: String?
}

/// Open Food Facts REST client. Free, no key; be a good citizen with a
/// descriptive User-Agent per their terms.
struct OpenFoodFactsProvider: FoodDatabaseProvider {
    var session: URLSession = .shared

    private static let userAgent = "\(BrandConfig.appName) - iOS - \(BrandConfig.supportEmail)"

    func searchBarcode(_ barcode: String) async throws -> FoodItem? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        guard decoded.status == 1, let product = decoded.product else { return nil }
        return product.foodItem(barcode: barcode)
    }

    func searchText(_ query: String) async throws -> [FoodItem] {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        return decoded.products.compactMap { $0.foodItem(barcode: $0.code) }
    }
}

// MARK: - Open Food Facts DTOs

private struct OFFProductResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFSearchResponse: Decodable {
    let products: [OFFProduct]
}

private struct OFFProduct: Decodable {
    let productName: String?
    let brands: String?
    let code: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case code
        case nutriments
    }

    func foodItem(barcode: String?) -> FoodItem? {
        guard let name = productName, !name.isEmpty, let nutriments else { return nil }
        return FoodItem(
            name: name,
            brand: brands,
            kcalPer100g: nutriments.energyKcal100g ?? 0,
            proteinPer100g: nutriments.proteins100g ?? 0,
            carbsPer100g: nutriments.carbohydrates100g ?? 0,
            fatPer100g: nutriments.fat100g ?? 0,
            barcode: barcode
        )
    }
}

private struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }
}
