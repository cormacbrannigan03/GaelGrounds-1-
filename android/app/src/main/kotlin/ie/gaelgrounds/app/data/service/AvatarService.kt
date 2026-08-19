package ie.gaelgrounds.app.data.service

import ie.gaelgrounds.app.data.Supa
import io.github.jan.supabase.storage.storage
import java.util.UUID

/** Mirrors ios/GaelGrounds/Services/AvatarService.swift. */
object AvatarService {
    private const val BUCKET = "avatars"

    suspend fun upload(jpegBytes: ByteArray, userId: String): String {
        val path = "$userId/${UUID.randomUUID()}.jpg"
        Supa.client.storage.from(BUCKET).upload(path, jpegBytes)
        return Supa.client.storage.from(BUCKET).publicUrl(path)
    }
}
