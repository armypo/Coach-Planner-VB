//
//  Item.swift
//  Coach Planner VB
//
//  Created by Christopher Dionne on 2026-03-18.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
