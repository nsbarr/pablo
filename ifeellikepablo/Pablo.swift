//
//  Pablo.swift
//  ifeellikepablo
//
//  Created by Nick Barr on 2/14/17.
//  Copyright © 2017 poemsio. All rights reserved.
//



import Foundation
import UIKit


class Pablo {
    var uid: String?
    var image = UIImage()
    var path = UIBezierPath().cgPath
    var dateCreated = NSDate()
    
    init(uid: String?, image: UIImage!, path: CGPath!, dateCreated: NSDate!) {
        self.uid = uid
        self.image = image
        self.path = path
        self.dateCreated = dateCreated
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
