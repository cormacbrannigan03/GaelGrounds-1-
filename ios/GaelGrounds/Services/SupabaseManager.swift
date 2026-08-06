import Foundation
import Supabase

/// Wraps the single shared SupabaseClient instance used across the app.
///
/// NOTE: this file targets the `supabase-swift` v2 "Supabase" package
/// (https://github.com/supabase/supabase-swift). The `SupabaseClientOptions`
/// initializer shape below is accurate as of the version this was written
/// against, but the SDK's options/realtime API has shifted across major
/// versions before — if Xcode reports an initializer mismatch here, check
/// the "Supabase" package's current `Types.swift` for the current shape.
enum Supa {
    static let client: SupabaseClient = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom(decodePostgresDate)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        return SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(
                db: .init(decoder: decoder, encoder: encoder)
            )
        )
    }()
}

/// Postgres/PostgREST timestamps come back as ISO 8601, sometimes with
/// fractional seconds and sometimes without. Plain `date` columns (e.g.
/// matches.match_date) come back as bare 'YYYY-MM-DD' with no time
/// component at all — try all three before giving up.
private func decodePostgresDate(_ decoder: Decoder) throws -> Date {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)

    let withFractional = ISO8601DateFormatter()
    withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = withFractional.date(from: raw) {
        return date
    }

    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    if let date = plain.date(from: raw) {
        return date
    }

    let dateOnly = DateFormatter()
    dateOnly.calendar = Calendar(identifier: .iso8601)
    dateOnly.timeZone = TimeZone(identifier: "UTC")
    dateOnly.dateFormat = "yyyy-MM-dd"
    if let date = dateOnly.date(from: raw) {
        return date
    }

    throw DecodingError.dataCorruptedError(
        in: try decoder.singleValueContainer(),
        debugDescription: "Could not decode date string \(raw)"
    )
}
