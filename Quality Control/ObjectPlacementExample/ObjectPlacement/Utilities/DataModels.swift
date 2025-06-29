//
//  DataModels.swift
//  Quality Control
//
//  Created by Melike SEYİTOĞLU on 9.12.2024.
//

import Foundation

struct InspectionPoint : Identifiable {
            let id = UUID()
            let name: String
            let position: SIMD3<Float>
    var count: Int?              // e.g. number of occurrences
    var hasCount: Bool
    
    var description: String?     // detailed information
    var hasDescription: Bool
    
    var isCorrect: Bool?         // replaced 'exists' with 'isCorrect'
    var hasIsCorrect: Bool
}

// Simple annotation model for reports
struct ReportAnnotation: Identifiable {
    let id: String
    var title: String
    var description: String
    var yesNoAnswer: Bool? // nil = "Not Set", true = "Yes", false = "No"
    
    init(id: String = UUID().uuidString, title: String, description: String, yesNoAnswer: Bool? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.yesNoAnswer = yesNoAnswer
    }
    
    var yesNoAnswerText: String {
        switch yesNoAnswer {
        case .some(true):
            return "Yes"
        case .some(false):
            return "No"
        case .none:
            return "Not Set"
        }
    }
}

// Updated VirtualObject to include annotations
struct VirtualObject {
    var name: String
    var width: Double
    var height: Double
    var depth: Double
    var inspectionPoints: [InspectionPoint]
    var annotations: [ReportAnnotation] = []
}
