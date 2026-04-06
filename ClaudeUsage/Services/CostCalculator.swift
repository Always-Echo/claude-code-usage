import Foundation

struct CostCalculator {
    struct ModelPricing {
        let inputPerMillion: Double
        let outputPerMillion: Double
        let cacheCreationPerMillion: Double
        let cacheReadPerMillion: Double
    }

    private let pricingTable: [(prefix: String, pricing: ModelPricing)] = [
        ("claude-opus-4",    ModelPricing(inputPerMillion: 15,   outputPerMillion: 75,  cacheCreationPerMillion: 18.75, cacheReadPerMillion: 1.50)),
        ("claude-sonnet-4",  ModelPricing(inputPerMillion: 3,    outputPerMillion: 15,  cacheCreationPerMillion: 3.75,  cacheReadPerMillion: 0.30)),
        ("claude-haiku-4-5", ModelPricing(inputPerMillion: 0.80, outputPerMillion: 4,   cacheCreationPerMillion: 1.0,   cacheReadPerMillion: 0.08)),
        ("claude-haiku-3-5", ModelPricing(inputPerMillion: 0.80, outputPerMillion: 4,   cacheCreationPerMillion: 1.0,   cacheReadPerMillion: 0.08)),
    ]

    private let defaultPricing = ModelPricing(
        inputPerMillion: 3,
        outputPerMillion: 15,
        cacheCreationPerMillion: 3.75,
        cacheReadPerMillion: 0.30
    )

    func cost(for entry: UsageEntry) -> Double {
        if let costUSD = entry.costUSD {
            return costUSD
        }

        guard let usage = entry.message?.usage else { return 0 }
        let model = entry.message?.model ?? ""
        let pricing = pricingTable.first(where: { model.hasPrefix($0.prefix) })?.pricing ?? defaultPricing

        let input = Double(usage.inputTokens ?? 0)
        let output = Double(usage.outputTokens ?? 0)
        let cacheCreate = Double(usage.cacheCreationInputTokens ?? 0)
        let cacheRead = Double(usage.cacheReadInputTokens ?? 0)

        return (input * pricing.inputPerMillion
            + output * pricing.outputPerMillion
            + cacheCreate * pricing.cacheCreationPerMillion
            + cacheRead * pricing.cacheReadPerMillion) / 1_000_000
    }

    /// Savings from cache reads: cost avoided by using cache instead of full input pricing.
    func cacheSavings(for entry: UsageEntry) -> Double {
        guard let usage = entry.message?.usage else { return 0 }
        let model = entry.message?.model ?? ""
        let pricing = pricingTable.first(where: { model.hasPrefix($0.prefix) })?.pricing ?? defaultPricing
        let cacheRead = Double(usage.cacheReadInputTokens ?? 0)
        let savingsPerMillion = pricing.inputPerMillion - pricing.cacheReadPerMillion
        return cacheRead * savingsPerMillion / 1_000_000
    }
}
