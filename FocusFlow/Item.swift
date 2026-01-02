//
//  Item.swift
//  FocusFlow
//
//  Created by Devon Martin on 1/2/2026.
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
