//
//  SwiftUIView.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 11.01.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit
import ARKit
import UIKit

struct InspectionView: View {
    var appState: AppState
    
    var body: some View {
        VStack {
            Text("Inspect Object")
                .font(.title)
                .padding()
            

            Spacer()
        }
        .padding()
        .onAppear {
                    addInspectionPoints()
                }
                .onDisappear {
                    removeInspectionPoints()
                }
        .navigationTitle("Inspection")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func addInspectionPoints() {
        guard let object = appState.placementManager?.placementState.placedObject else {
            print("No object available for inspection points.")
            return
        }

        let objectName = object.fileName
        let loader = InspectionPointLoader()

        // Load inspection points for the specific object name
        let inspectionPointsData = loader.getInspectionPoints(for: objectName)

        Task {
            // Dynamically generate inspection points for the placed object
            await appState.placementManager?.generateInspectionPoints(for: object)

            // Update AppState with the loaded inspection points
            for (type, pointData) in inspectionPointsData {
                // Check if the inspection point already exists
                if appState.inspectionPoints[objectName]?[type] == nil {
                    // Only add the inspection point if it doesn't already exist
                    let inspectionPoint = InspectionPoint(
                        name: pointData.name,
                        position: pointData.position,
                        count: pointData.count,
                        hasCount: pointData.hasCount,
                        description: pointData.description,
                        hasDescription: pointData.hasDescription,
                        isCorrect: pointData.isCorrect,
                        hasIsCorrect: pointData.hasIsCorrect
                    )
                    appState.inspectionPoints[objectName, default: [:]][type] = inspectionPoint
                } else {
                    print("Inspection point for type \(type.rawValue) already exists and won't be overwritten.")
                }
            }
        }
    }

    private func removeInspectionPoints() {
        Task {
            await appState.placementManager?.removeInspectionPoints()
        }
    }
}
