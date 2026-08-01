import Foundation
import UIKit
import Supabase

/// Uploads user-submitted ground photos to the public `ground-photos`
/// storage bucket. Photos are attached to the uploader's `user_visits` row
/// for that ground (see `GroundCheckInPanel`) rather than tracked here.
enum GroundPhotoService {
    private static let bucket = "ground-photos"

    enum UploadError: Error {
        case invalidImage
    }

    /// Re-encodes whatever image data PhotosPicker hands back (HEIC, PNG,
    /// ...) as JPEG before upload, so the bucket's content type and this
    /// app's display code never have to branch on source format.
    static func upload(rawImageData: Data, userId: UUID, groundId: UUID) async throws -> String {
        guard let uiImage = UIImage(data: rawImageData),
              let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            throw UploadError.invalidImage
        }

        let path = "\(userId.uuidString)/\(groundId.uuidString)/\(UUID().uuidString).jpg"
        try await Supa.client.storage.from(bucket).upload(
            path,
            data: jpegData,
            options: FileOptions(contentType: "image/jpeg")
        )
        return try Supa.client.storage.from(bucket).getPublicURL(path: path).absoluteString
    }
}
