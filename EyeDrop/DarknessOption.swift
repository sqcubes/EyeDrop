//
//  DarknessOption.swift
//  EyeDrop
//
//  Created by Mattijs on 29/01/2017.
//  Copyright © 2017 Mattijs. All rights reserved.
//

import Foundation


public enum DarknessOption: Int {
    case High = 0
    case Medium = 1
    case Low = 2
    
    public var alpha: CGFloat {
        switch self {
        case .High: return 1.0
        case .Medium: return 0.75
        case .Low: return 0.5
        }
    }
}
