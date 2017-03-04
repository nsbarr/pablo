//
//  ScreenWidth.swift
//  ifeellikepablo
//
//  Created by Nick Barr on 2/27/17.
//  Copyright © 2017 poemsio. All rights reserved.
//

import UIKit

public enum ScreenWidth: Int {
    case iPhone5 = 320
    case iPhone6 = 375
    case iPhone6Plus = 414
    
    init?(logicalWidth: CGFloat) {
        self.init(rawValue: Int(logicalWidth))
    }
    
    static func initWith(pixelWidth: CGFloat) -> ScreenWidth? {
        // get all known screen widths
        // filter them to only include the one(s) that matches our pixelWidth
        let allWidths: [ScreenWidth] = [.iPhone5, .iPhone6, .iPhone6Plus]
        
        let result = allWidths.filter { width in
            return width.pixelWidth == pixelWidth
        }.first
        
        return result
    }
    
    var floatValue: CGFloat {
        return CGFloat(rawValue)
    }
    
    var resolution: CGFloat {
        switch self {
        case ScreenWidth.iPhone5, ScreenWidth.iPhone6:
            return 2
        case ScreenWidth.iPhone6Plus:
            return 3
        }
    }
    var pixelWidth: CGFloat {
        return floatValue*resolution
    }
}
