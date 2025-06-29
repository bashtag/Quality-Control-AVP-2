//
//  InspectionPointLoader.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 13.01.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation

struct InspectionPointData: Codable {
    let objectName: String
    let inspectionType: String
    let inspectionName: String
    let inspectionPoint: Position
}

struct Position: Codable {
    let x: Float
    let y: Float
    let z: Float
}

class InspectionPointLoader {
    // A map of object names to their associated inspection points.
    private var inspectionPointsByObject: [String: [InspectionPointData]] = [:]
    
    // The JSON file name containing the inspection points.
    static let inspectionPointsFileName = "inspectionPoints.json"
    
    /// Initialize the loader and optionally load persisted inspection points.
    init() {
        loadInspectionPoints()
    }


    
    /// Load inspection points from a JSON file in the app bundle (development environment).
    private func loadInspectionPoints() {
        var inspectionPoints: [InspectionPointData] = []
            
        // Look for the file in the main bundle
        guard let fileURL = Bundle.main.url(forResource: "inspectionPoints", withExtension: "json") else {
            print("Could not find 'inspectionPoints.json' in the main bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let loadedData = try JSONDecoder().decode([InspectionPointData].self, from: data)
            
            // Group inspection points by object name
            for point in loadedData {
                if inspectionPointsByObject[point.objectName] == nil {
                    inspectionPointsByObject[point.objectName] = []
                }
                inspectionPointsByObject[point.objectName]?.append(point)
            }
            
            print("Inspection points successfully loaded from '\(fileURL.lastPathComponent)'.")
        } catch {
            print("Failed to load inspection points from file: \(error.localizedDescription)")
        }
    }
    
    func getInspectionPoints(for objectName: String) -> [PlacementManager.InspectionPointType: InspectionPoint] {
        var inspectionPoints: [PlacementManager.InspectionPointType: InspectionPoint] = [:]
        
        guard let points = inspectionPointsByObject[objectName] else {
            print("No inspection points found for object: \(objectName)")
            return inspectionPoints
        }
        
        for pointData in points {
            guard let type = PlacementManager.InspectionPointType(rawValue: pointData.inspectionType) else {
                print("Invalid inspection type: \(pointData.inspectionType)")
                continue
            }
            
            let inspectionPoint = InspectionPoint(
                name: pointData.inspectionName, // Use the inspectionName field
                position: SIMD3<Float>(pointData.inspectionPoint.x, pointData.inspectionPoint.y, pointData.inspectionPoint.z),
                count: nil,
                hasCount: type == .forCount,
                description: nil,
                hasDescription: type == .forDescription,
                isCorrect: nil,
                hasIsCorrect: type == .forYesNoQuestion
            )
            
            inspectionPoints[type] = inspectionPoint
        }
        
        return inspectionPoints
    }


    
//    /// Get all inspection points for a specific object name.
//    /// - Parameter objectName: The name of the object to fetch data for.
//    /// - Returns: A dictionary of `[PlacementManager.InspectionPointType: InspectionPoint]` for the given object name.
//    func getInspectionPoints(for objectName: String) -> [PlacementManager.InspectionPointType: InspectionPoint] {
//        var inspectionPoints: [PlacementManager.InspectionPointType: InspectionPoint] = [:]
//        
//        guard let points = inspectionPointsByObject[objectName] else {
//            print("No inspection points found for object: \(objectName)")
//            return inspectionPoints
//        }
//        
//        for pointData in points {
//            guard let type = PlacementManager.InspectionPointType(rawValue: pointData.inspectionType) else {
//                print("Invalid inspection type: \(pointData.inspectionType)")
//                continue
//            }
//            
//            let inspectionPoint = InspectionPoint(
//                name: pointData.objectName,
//                position: SIMD3<Float>(Float(pointData.inspectionPoint.x), Float(pointData.inspectionPoint.y), Float(pointData.inspectionPoint.z)),
//                count: nil,
//                hasCount: type == .forCount,
//                description: nil,
//                hasDescription: type == .forDescription,
//                isCorrect: nil,
//                hasIsCorrect: type == .forYesNoQuestion
//            )
//            
//            inspectionPoints[type] = inspectionPoint
//        }
//        
//        return inspectionPoints
//    }
}
