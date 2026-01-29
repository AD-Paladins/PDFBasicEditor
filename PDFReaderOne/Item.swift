//
//  Item.swift
//  PDFReaderOne
//
//  Created by andres paladines on 1/28/26.
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
