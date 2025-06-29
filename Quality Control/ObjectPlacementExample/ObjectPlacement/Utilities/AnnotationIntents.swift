//
//  AnnotationIntents.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 21.06.2025.
//  Copyright © 2025 Apple. All rights reserved.
//
import AppIntents
 
struct SearchAnnotationsIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Annotations In QualityControl"
    static var description = IntentDescription("Search annotation titles or descriptions.")
    static var openAppWhenRun: Bool = true
 
    @Parameter(title: "Search Text")
    var searchText: String
 
//    func perform() async throws -> some IntentResult {
//        UserDefaults.standard.set(query, forKey: "siriAnnotationQuery")
//        return .result(dialog: "Searching annotations for '\(query)'")
//    }
    
    func perform() async throws -> some IntentResult {
        AppIntentsController.shared.searchText = searchText
        
        return .result()
    }
}
 
