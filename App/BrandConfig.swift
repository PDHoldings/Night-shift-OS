import Foundation

/// Working title is "NightShift OS"; final brand TBD. Nothing else in the
/// codebase may hardcode a brand string — always go through here.
enum BrandConfig {
    static let appName = "NightShift OS"
    static let companyName = "Phanetics Digital Holdings, LLC"
    static let supportEmail = "support@phanetics.com"
    /// Shown in Coach and onboarding. Wellness framing only — no medical claims.
    static let wellnessDisclaimer = """
    \(BrandConfig.appName) offers general wellness guidance for shift workers. \
    It does not diagnose, treat, or manage any medical condition. Talk to a \
    clinician about persistent sleep or health problems.
    """
}
