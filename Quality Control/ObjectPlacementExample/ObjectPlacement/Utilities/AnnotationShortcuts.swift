//
//  AnnotationShortcuts.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 21.06.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import AppIntents
 
struct AnnotationShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: SearchAnnotationsIntent(),
                phrases: [
                    "Search annotations in \(.applicationName)",
                    "Search annotations for \(\.$searchText)",
                                   "Find \(\.$searchText) in annotations"
                ],
                shortTitle: "Search Annotations",
                systemImageName: "magnifyingglass"
            )
    }
}
