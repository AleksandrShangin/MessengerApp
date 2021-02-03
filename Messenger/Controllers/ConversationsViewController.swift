//
//  ViewController.swift
//  Messenger
//
//  Created by Alex on 2/2/21.
//

import UIKit


class ConversationsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
    }

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let isLoggedIn = UserDefaults.standard.bool(forKey: "loggedIn")
        
        if !isLoggedIn {
            let vc = LogInViewController()
            
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            
            present(nav, animated: false)
        }
    }

}

