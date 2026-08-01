import Foundation
import Supabase

/// Generic "reload when this table changes" subscription, used by any view
/// that lists or displays `matches`/`honours` so provider-synced updates
/// (a score coming in, a new fixture appearing) show up live instead of
/// only on the next pull-to-refresh. CheckInPanel/GroundCheckInPanel have
/// their own inline version of this same pattern filtered to one row's
/// check-ins — this is the table-wide equivalent for read-only data.
enum RealtimeWatcher {
    static func watch(table: String, filter: String? = nil, onChange: @escaping () -> Void) -> (channel: RealtimeChannelV2, task: Task<Void, Never>) {
        let channel = Supa.client.realtimeV2.channel("watch-\(table)-\(UUID().uuidString)")
        let changes: AsyncStream<AnyAction>
        if let filter {
            changes = channel.postgresChange(AnyAction.self, schema: "public", table: table, filter: filter)
        } else {
            changes = channel.postgresChange(AnyAction.self, schema: "public", table: table)
        }

        let task = Task {
            await channel.subscribe()
            for await _ in changes {
                onChange()
            }
        }

        return (channel, task)
    }

    static func stop(channel: RealtimeChannelV2?, task: Task<Void, Never>?) {
        task?.cancel()
        Task { await channel?.unsubscribe() }
    }
}
