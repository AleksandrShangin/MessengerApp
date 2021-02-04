import UIKit
import FirebaseAuth



class ConversationsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
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

