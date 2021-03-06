import Foundation
import FirebaseAuth
import FirebaseDatabase
import MessageKit
import CoreLocation


/// Manager object to read and write data to real time firebase database
final class DatabaseManager {
    
    /// Shared instance of class
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    
    private init() {}
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
}


extension DatabaseManager {
    
    /// Returns dictionary node at child path
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child("\(path)").observe(.value) { (snapshot) in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }
}


// MARK: - Account Management

extension DatabaseManager {
    
    /// Check if user exists for given email
    /// Parameters
    /// - `email`:                  Target email to be checked
    /// - `completion`:       Async closure to return with result
    func userExists(with email: String, completion: @escaping (Bool) -> Void) {
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child(safeEmail).observeSingleEvent(of: .value) { (dataSnapshot) in
            guard dataSnapshot.exists() else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    /// Inserts new users to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue(["firstName": user.firstName, "lastName": user.lastName]) { [weak self] (error, _) in
            guard let strongSelf = self else {
                return
            }
            guard error == nil else {
                print("Failed to write to database")
                completion(false)
                return
            }
            strongSelf.database.child("users").observeSingleEvent(of: .value) { (dataSnapshot) in
                if var userCollection = dataSnapshot.value as? [[String: String]] {
                    // Append to User Dictionary
                    let newElement = ["name": user.firstName + " " + user.lastName, "email": user.safeEmail]
                    userCollection.append(newElement)
                    strongSelf.database.child("users").setValue(userCollection) { (error, _) in
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
                    strongSelf.database.child("users").setValue(newCollection) { (error, _) in
                        guard error == nil else {
                            return
                        }
                        completion(true)
                    }
                }
            }
        }
    }
    
    /// Gets all users from database
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
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

//MARK: - Sending Messages / Conversations
extension DatabaseManager {
    
    /// Creates new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentEmail = Auth.auth().currentUser?.email else {
            return
        }
        guard let currentName = UserDefaults.standard.value(forKey: "name") else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child("\(safeEmail)")
        ref.observe(.value) { [weak self] (snapshot) in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("User not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationId = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let recipient_newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            // Update recipient conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { [weak self] (snapshot) in
                print("\nWE GOT TO THE RECIPIENT CONVERSATIONS CREATION\n")
                if var conversations = snapshot.value as? [[String: Any]] {
                    // Append
                    print("\nENTRY EXISTS, APPENDING...")
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                } else {
                    // Create
                    print("\nNO INITIAL VALUE, CREATING CHILD NODE...")
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            }
            
            // Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversation array exists for current user
                // you should append
                conversations.append(newConversationData)
                userNode["conversations"] =
                ref.setValue(userNode) { [weak self] (error, _) in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConvesation(name: name, conversationID: conversationId, firstMessage: firstMessage, completion: completion)
                }
            } else {
                // create neW conversations array
                userNode["conversations"] = [
                    newConversationData
                ]
                ref.setValue(userNode) { [weak self] (error, _) in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConvesation(name: name, conversationID: conversationId, firstMessage: firstMessage, completion: completion)
                }
            }
        }
    }
    
    private func finishCreatingConvesation(name: String, conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        var message = ""
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        guard let currenUsertEmail = Auth.auth().currentUser?.email else {
            completion(false)
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currenUsertEmail)
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": safeEmail,
            "is_read": false,
            "name": name
        ]
        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        print("Adding convo: \(conversationID)")
        
        database.child("\(conversationID)").setValue(value) { (error, _) in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        database.child("\(email)/conversations").observe(.value) { (snapshot) in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let conversations: [Conversation] = value.compactMap { (dictionary) in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool,
                      let message = latestMessage["message"] as? String else {
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: conversationId, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            }
            completion(.success(conversations))
        }
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value) { (snapshot) in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let messages: [Message] = value.compactMap { (dictionary) in
                guard let name = dictionary["name"] as? String,
                      let content = dictionary["content"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let messageId = dictionary["id"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let type = dictionary["type"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString) else {
                    return nil
                }
                
                var kind: MessageKind?
                if type == "photo" {
                    // photo
                    guard let imageUrl = URL(string: content), let placeHolder = UIImage(named: "plus") else {
                        return nil
                    }
                    let media = Media(url: imageUrl, image: nil, placeholderImage: placeHolder, size: CGSize(width: 300, height: 300))
                    kind = .photo(media)
                }
                else if type == "video" {
                    guard let videoUrl = URL(string: content), let placeHolder = UIImage(named: "video") else {
                        return nil
                    }
                    let media = Media(url: videoUrl, image: nil, placeholderImage: placeHolder, size: CGSize(width: 300, height: 300))
                    kind = .video(media)
                }
                
                else if type == "location" {
                    let locationComponents = content.components(separatedBy: ",")
                    guard let longitude = Double(locationComponents[0]), let latitude = Double(locationComponents[1]) else {
                        return nil
                    }
                    
                    let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: CGSize(width: 300, height: 300))
                    
                    kind = .location(location)
                }
                
                else {
                    // text
                    kind = .text(content)
                }
                
                guard let finalKind = kind else {
                    return nil
                }
                
                let sender = Sender(photoURL: "", senderId: senderEmail, displayName: name)
                return Message(sender: sender, messageId: messageId, sentDate: date, kind: finalKind)
            }
            completion(.success(messages))
        }
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation: String, otherUserEmail: String, name: String, newMessage: Message, completion: @escaping (Bool) -> Void) {
        // Add new message to messages
        // Update sender latest message
        // Update recipient latest message
        guard let currenUsertEmail = Auth.auth().currentUser?.email else {
            completion(false)
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currenUsertEmail)
        
        database.child("\(conversation)/messages").observeSingleEvent(of: .value) { [weak self] (snapshot) in
            guard let strongSelf = self else {
                return
            }
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch newMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
                break
            case .video(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
                break
            case .location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": safeEmail,
                "is_read": false,
                "name": name
            ]
            
            currentMessages.append(newMessageEntry)
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages) { (error, _) in
                guard error == nil else {
                    completion(false)
                    return
                }
                
                strongSelf.database.child("\(safeEmail)/conversations").observeSingleEvent(of: .value) { (snapshot) in
                    var databaseEntryConversations = [[String: Any]]()
                    let updatedValue: [String: Any] = ["date": dateString, "is_read": false, "message": message]
                    if var currentUserConversations = snapshot.value as? [[String: Any]] {
                        var targetConversation: [String: Any]?
                        var position = 0
                        
                        for conversationDictionary in currentUserConversations {
                            if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                targetConversation = conversationDictionary
                                break
                            }
                            position += 1
                        }
                        
                        if var targetConversation = targetConversation {
                            targetConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targetConversation
                            databaseEntryConversations = currentUserConversations
                        } else {
                            let newConversationData: [String: Any] = [
                                "id": conversation,
                                "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                                "name": name,
                                "latest_message": updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                        
                    } else {
                        let newConversationData: [String: Any] = [
                            "id": conversation,
                            "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                            "name": name,
                            "latest_message": updatedValue
                        ]
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }
                    
                    strongSelf.database.child("\(safeEmail)/conversations").setValue(databaseEntryConversations) { (error, _) in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        // Update latest message for recipient user
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { (snapshot) in
                            let updatedValue: [String: Any] = ["date": dateString, "is_read": false, "message": message]
                            
                            var databaseEntryConversations = [[String: Any]]()
                            
                            guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                                return
                            }
                            
                            if var otherUserConversations = snapshot.value as? [[String: Any]]  {
                                var targetConversation: [String: Any]?
                                var position = 0
                                
                                for conversationDictionary in otherUserConversations {
                                    if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                        targetConversation = conversationDictionary
                                        break
                                    }
                                    position += 1
                                }
                                
                                if var targetConversation = targetConversation {
                                    targetConversation["latest_message"] = updatedValue
                                    otherUserConversations[position] = targetConversation
                                    databaseEntryConversations = otherUserConversations
                                } else {
                                    // failed to find in current collection
                                    let newConversationData: [String: Any] = [
                                        "id": conversation,
                                        "other_user_email": DatabaseManager.safeEmail(emailAddress: currenUsertEmail),
                                        "name": currentName,
                                        "latest_message": updatedValue
                                    ]
                                    otherUserConversations.append(newConversationData)
                                    databaseEntryConversations = otherUserConversations
                                }
                                
                            } else {
                                // current collection does not exist
                                let newConversationData: [String: Any] = [
                                    "id": conversation,
                                    "other_user_email": DatabaseManager.safeEmail(emailAddress: currenUsertEmail),
                                    "name": currentName,
                                    "latest_message": updatedValue
                                ]
                                databaseEntryConversations = [
                                    newConversationData
                                ]
                            }
                            
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(databaseEntryConversations) { (error, _) in
                                guard error == nil else {
                                    completion(false)
                                    return
                                }
                                completion(true)
                            }
                        }
                    }
                }
                
            }
            
        }
    }
    
    func deleteConversation(conversationId: String, completion: @escaping (Bool) -> Void) {
        guard let email = Auth.auth().currentUser?.email else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        print("Deleting conversation with id: \(conversationId)")
        // Get all conversations for current user
        // Delete conversation in collection with target id
        // Reset those conversations for the user in database
        let ref = database.child("\(safeEmail)/conversations")
        ref.observeSingleEvent(of: .value) { (snapshot) in
            if var conversations = snapshot.value as? [[String: Any]] {
                var positionToRemove = 0
                for conversation in conversations {
                    if let id = conversation["id"] as? String, id == conversationId {
                        print("Found conversation to delete")
                        break
                    }
                    positionToRemove += 1
                }
                conversations.remove(at: positionToRemove)
                ref.setValue(conversations) { (error, _) in
                    guard error == nil else {
                        completion(false)
                        print("Failed to write new conversation array")
                        return
                    }
                    print("Deleted conversation")
                    completion(true)
                }
            }
        }
        
    }
    
    public func conversationExists(with targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
        let safeRecipientEmail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
        guard let senderEmail = Auth.auth().currentUser?.email else {
            return
        }
        let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)
        
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value) { (snapshot) in
            guard let collection = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            // Iterate and find conversation with target sender
            if let conversation = collection.first(where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else {
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }) {
                // Get id
                guard let id = conversation["id"] as? String else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(id))
                return
            }
            completion(.failure(DatabaseError.failedToFetch))
        }
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
