import Foundation
import FirebaseDatabase



final class DatabaseManager {
    
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
}

// MARK: - Account Managment
extension DatabaseManager {
    
    func userExists(with email: String, completion: @escaping (Bool) -> Void) {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        database.child(safeEmail).observeSingleEvent(of: .value) { (dataSnapshot) in
            guard dataSnapshot.value as? String != nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    /// Inserts new users to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue(["firstName": user.firstName, "lastName": user.lastName]) { (error, ref) in
            guard error == nil else {
                print("Failed to write to database")
                completion(false)
                return
            }
            self.database.child("users").observeSingleEvent(of: .value) { (dataSnapshot) in
                if var userCollection = dataSnapshot.value as? [[String: String]] {
                    // Append to User Dictionary
                    let newElement = ["name": user.firstName + " " + user.lastName, "email": user.safeEmail]
                    userCollection.append(newElement)
                    self.database.child("users").setValue(userCollection) { (error, _) in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                } else {
                    // Create that Dictionary
                    let newCollection: [[String: String]] = [
                        ["name": user.firstName + " " + user.lastName,
                         "email": user.safeEmail
                        ]
                    ]
                    self.database.child("users").setValue(newCollection) { (error, _) in
                        guard error == nil else {
                            return
                        }
                        completion(true)
                    }
                }
            }
        }
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void ) {
        database.child("users").observeSingleEvent(of: .value) { (dataSnapshot) in
            guard let value = dataSnapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
    
}




struct ChatAppUser {
    
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}
