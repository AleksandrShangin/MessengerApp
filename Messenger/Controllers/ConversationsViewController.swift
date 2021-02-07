import UIKit
import FirebaseAuth



class ConversationsViewController: UIViewController {

    private let tableView: UITableView = {
        let table = UITableView()
        table.register
        return table
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        validateAuth()
    }
    
    func validateAuth() {
        if Auth.auth().currentUser == nil {
            let vc = LogInViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false)
        } else {
            print("\n\(Auth.auth().currentUser?.email) \(Auth.auth().currentUser?.uid)\n")
        }
    }
    
}


