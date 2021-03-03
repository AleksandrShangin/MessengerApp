//
//  ProfileViewModel.swift
//  Messenger
//
//  Created by Alex on 3/2/21.
//

import Foundation



enum ProfileViewModelType {
    case info, logout
}


struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)?
}
