import Foundation
import UIKit
import Supabase

/// Uploads a user's profile photo to the public `avatars` storage bucket,
/// mirroring GroundPhotoService's conventions (re-encode to JPEG, one
/// object per owner folder). Unlike ground photos, each user has exactly
/// one avatar, so the upload always targets the same path and overwrites
/// (upsert) rather than accumulating new objects per upload.
enum AvatarService {
    private static let bucket = "avatars"

    enum UploadError: Error {
        case invalidImage
    }

    static func upload(rawImageData: Data, userId: UUID) async throws -> String {
        guard let uiImage = UIImage(data: rawImageData),
              let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            throw UploadError.invalidImage
        }

        let path = "\(userId.uuidString)/avatar.jpg"
        try await Supa.client.storage.from(bucket).upload(
            path,
            data: jpegData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )

        // The path never changes on re-upload, so a cache-busting query
        // param is appended to force clients to refetch the new image
        // instead of showing a stale cached one at the same URL.
        let publicURL = try Supa.client.storage.from(bucket).getPublicURL(path: path)
        var components = URLComponents(url: publicURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "t", value: "\(Int(Date().timeIntervalSince1970))")]
        return components?.url?.absoluteString ?? publicURL.absoluteString
    }
}
