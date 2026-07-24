import Foundation

/// Distinct navigation-value wrapper types so `NavigationStack` can tell a
/// match id apart from a ground id or county id (a bare `UUID` would be
/// ambiguous across multiple `.navigationDestination(for:)` modifiers in the
/// same stack).
struct MatchRoute: Hashable { let id: UUID }
struct GroundRoute: Hashable { let id: UUID }
struct CountyRoute: Hashable { let id: UUID }
