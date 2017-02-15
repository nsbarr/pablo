//
//  PabloFeedCollectionViewCell.swift
//  ifeellikepablo
//
//  Created by Nick Barr on 2/14/17.
//  Copyright © 2017 poemsio. All rights reserved.
//

import Foundation
import UIKit

class PabloFeedCollectionViewCell: UICollectionViewCell {
    static let identifier = "PabloFeedCollectionViewCell"
    //TODO: add the pathstring into this guy
    var image: UIImage? {
        didSet {
            self.imageView.image = image
            // self.imagePath = imagePath
        }
    }
    
    fileprivate let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
//    fileprivate var imagePath: CGPath = {
//        let bezier = UIBezierPath()
//        let imagePath = bezier.cgPath
//        return imagePath
//    }()
    
    //        fileprivate let titleLabel: UILabel = {
    //            let label = UILabel()
    //            label.font = UIFont.boldSystemFont(ofSize: 12)
    //            label.textColor = .black
    //            return label
    //        }()
    //
    //        fileprivate let subtitleLabel: UILabel = {
    //            let label = UILabel()
    //            label.font = UIFont.systemFont(ofSize: 11)
    //            label.textColor = .darkGray
    //            return label
    //        }()
    //
    //        fileprivate let detailLabel: UILabel = {
    //            let label = UILabel()
    //            label.textColor = .gray
    //            label.font = UIFont.systemFont(ofSize: 11)
    //            return label
    //        }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.contentView.addSubview(self.imageView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.imageView.frame = self.contentView.bounds
    }
}
    
