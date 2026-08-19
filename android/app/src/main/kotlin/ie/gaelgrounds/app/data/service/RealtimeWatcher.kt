package ie.gaelgrounds.app.data.service

import ie.gaelgrounds.app.data.Supa
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Generic "reload when this table changes" subscription, used by any screen
 * that lists or displays data that can change from elsewhere in the app
 * (a check-in appearing, a score coming in). Mirrors
 * ios/GaelGrounds/Services/RealtimeWatcher.swift, merging insert/update/
 * delete into one callback the same way `AnyAction` does on iOS.
 */
object RealtimeWatcher {
    fun watch(
        scope: CoroutineScope,
        table: String,
        filterColumn: String? = null,
        filterValue: String? = null,
        onChange: () -> Unit,
    ): RealtimeChannel {
        val channel = Supa.client.channel("watch-$table-${UUID.randomUUID()}")

        val inserts = channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            this.table = table
            if (filterColumn != null && filterValue != null) filter(filterColumn, FilterOperator.EQ, filterValue)
        }
        val updates = channel.postgresChangeFlow<PostgresAction.Update>(schema = "public") {
            this.table = table
            if (filterColumn != null && filterValue != null) filter(filterColumn, FilterOperator.EQ, filterValue)
        }
        val deletes = channel.postgresChangeFlow<PostgresAction.Delete>(schema = "public") {
            this.table = table
            if (filterColumn != null && filterValue != null) filter(filterColumn, FilterOperator.EQ, filterValue)
        }

        scope.launch {
            channel.subscribe()
            merge(inserts, updates, deletes).collect { onChange() }
        }

        return channel
    }

    // Deliberately not tied to the caller's scope: this is typically called
    // from onCleared(), where viewModelScope is already being torn down and
    // a launch on it may never actually run. A short-lived, best-effort
    // unsubscribe on teardown is a reasonable use of GlobalScope here.
    @OptIn(DelicateCoroutinesApi::class)
    fun stop(channel: RealtimeChannel?) {
        channel ?: return
        GlobalScope.launch { channel.unsubscribe() }
    }
}
