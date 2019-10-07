//
//  DemoController.swift
//  HSVDemo
//
//  Created by Hector on 10/6/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation
import NetworkHandler

class DemoControllr {
    private(set) var users: [Users] = []
    
    let url = URL(string: "https://randomuser.me/api/?results=5&inc=name,email,picture")!
    
    init() {
        fetchUsers(with: url)
    }
    
    
    private func fetchUsers(with url: URL) {
        NetworkHandler.default.transferMahDatas(with: url.request) { result in
            do {
                let data = try result.get()
                print(data)
            } catch {
                NSLog("Error printing data: \(error)")
            }
        }
        
    }
    
    
    
}
