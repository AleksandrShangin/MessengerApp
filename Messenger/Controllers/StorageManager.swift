//
//  StorageManager.swift
//  Messenger
//
//  Created by Alex on 2/8/21.
//

import Foundation
import FirebaseStorage


final class StorageManager {
    
    static let shared = StorageManager()
    private let storage = Storage.storage().reference()
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    /// Uploads pictures to Firebase Storage and returns completion with URL String to  download
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data, metadata: nil) { (storageMetadata, error) in
            guard error == nil else {
                // Failed
                print("Failed to upload data to firebase for picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            self.storage.child("images/\(fileName)").downloadURL { (url, error) in
                guard let url = url else {
                    print("failed To Get Download Url")
                    completion(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                let urlString = url.absoluteString
                print("DownloadURL: \(urlString)")
                completion(.success(urlString))
            }
        }
    }
    
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDownloadUrl
    }
    
}
