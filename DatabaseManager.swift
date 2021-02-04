//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Alex on 2/4/21.
//

import Foundation
import FirebaseDatabase


final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
}

// MARK: - Account Managment
extension DatabaseManager {
    
    func userExists(with email: String, completion: @escaping ((Bool) -> Void)) {
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
    public func insertUser(with user: ChatAppUser) {
        database.child(user.safeEmail).setValue(["firstName": user.firstName, "lastName": user.lastName])
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
  //  let profilePictureUrl: String
}
