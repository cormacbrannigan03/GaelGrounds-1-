import Foundation
import UIKit
import Supabase

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

        let path = "\(userId.uuidString)/\(UUID().uuidString).jpg"
        try await Supa.client.storage.from(bucket).upload(
            path,
            data: jpegData,
            options: FileOptions(contentType: "image/jpeg")
        )
        return try Supa.client.storage.from(bucket).getPublicURL(path: path).absoluteString
    }
}
