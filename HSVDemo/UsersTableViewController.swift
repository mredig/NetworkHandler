//
//  TableViewController.swift
//  HSVDemo
//
//  Created by Hector on 10/6/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit

class UsersTableViewController: UITableViewController {

    let demoController = DemoControllr()
    
    lazy var refresher: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .black
        refreshControl.addTarget(self, action: #selector(refreshUsers), for: .valueChanged)
        return refreshControl
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.refreshControl = refresher
    }

    @objc
    func refreshUsers() {
        print("get user data")
        
        let deadline = DispatchTime.now() + .seconds(5)
        DispatchQueue.main.asyncAfter(deadline: deadline) {
            self.refresher.endRefreshing()
        }
    }
    
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 0
    }


}
