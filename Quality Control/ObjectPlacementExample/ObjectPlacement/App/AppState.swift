/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app’s overall state.
*/

import Foundation
import ARKit
import RealityKit

@Observable
class AppState {

    // DEBUG
    var immersiveSpaceOpened: Bool { placementManager != nil }
    var highlightedPoint: PlacementManager.InspectionPointType? = nil // The currently highlighted inspection point
    var isInspectionDetailsOpen: Bool = false // New flag
    var isAnnotationViewOpen: Bool = false // New flag
    
    var isAnnotationAdded: Bool = false // flag to open title-description set view

    // Store inspection points by type
//    var inspectionPoints: [PlacementManager.InspectionPointType: InspectionPoint] = [:]
    var inspectionPoints: [String: [PlacementManager.InspectionPointType: InspectionPoint]] = [:]

    func getInspectionPoint(for objectName: String, type: PlacementManager.InspectionPointType) -> InspectionPoint? {
            return inspectionPoints[objectName]?[type]
        }
        
        func updateInspectionPoint(
            for objectName: String,
            type: PlacementManager.InspectionPointType,
            count: Int? = nil,
            description: String? = nil,
            isCorrect: Bool? = nil
        ) {
            var point = inspectionPoints[objectName]?[type] ?? InspectionPoint(
                name: type.rawValue,
                position: SIMD3<Float>(),
                count: nil,
                hasCount: false,
                description: nil,
                hasDescription: false,
                isCorrect: nil,
                hasIsCorrect: false
            )

            if let count = count {
                point.count = count
                point.hasCount = true
            }

            if let description = description {
                point.description = description
                point.hasDescription = true
            }

            if let isCorrect = isCorrect {
                point.isCorrect = isCorrect
                point.hasIsCorrect = true
            }

            // Update the dictionary
            inspectionPoints[objectName, default: [:]][type] = point
        }
    
    // Interaction mode for controlling gestures
    enum InteractionMode: String {
        case rotation = "Rotation"
        case forwardBack = "Forward-Back"
        case leftRight = "Left-Right"
        case objectTracking = "Object Tracking"
    }

    var mode: InteractionMode? = nil // Tracks the currently selected mode
    
    enum AppStateViewMode: String {
        case addAnnotation = "addAnnotation"
        case viewAnnotations = "viewAnnotations"
        case other = "Other"
    }
    
    var viewMode: AppStateViewMode? = nil
    var isFocusedAnnotationChangable: Bool = true

    // END DEBUG
    
    private(set) weak var placementManager: PlacementManager? = nil

    private(set) var placeableObjectsByFileName: [String: PlaceableObject] = [:]
    private(set) var modelDescriptors: [ModelDescriptor] = []
    var selectedFileName: String?

    func immersiveSpaceOpened(with manager: PlacementManager) {
        placementManager = manager
    }
    
    func didLeaveImmersiveSpace() {
        // Remember which placed object is attached to which persistent world anchor when leaving the immersive space.
        placementManager = nil
        selectedFileName = nil
    }

    func setPlaceableObjects(_ objects: [PlaceableObject]) {
        placeableObjectsByFileName = objects.reduce(into: [:]) { map, placeableObject in
            map[placeableObject.descriptor.fileName] = placeableObject
        }

        // Sort descriptors alphabetically.
        modelDescriptors = objects.map { $0.descriptor }.sorted { lhs, rhs in
            lhs.displayName < rhs.displayName
        }
   }

    // MARK: - ARKit state

    var arkitSession = ARKitSession()
    var providersStoppedWithError = false
    var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    
    var allRequiredAuthorizationsAreGranted: Bool {
        worldSensingAuthorizationStatus == .allowed
    }

    var allRequiredProvidersAreSupported: Bool {
        WorldTrackingProvider.isSupported && PlaneDetectionProvider.isSupported && ObjectTrackingProvider.isSupported
    }

    var canEnterImmersiveSpace: Bool {
        allRequiredAuthorizationsAreGranted && allRequiredProvidersAreSupported
    }

    func requestWorldSensingAuthorization() async {
        let authorizationResult = await arkitSession.requestAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = authorizationResult[.worldSensing]!
    }
    
    func queryWorldSensingAuthorization() async {
        let authorizationResult = await arkitSession.queryAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = authorizationResult[.worldSensing]!
    }

    func monitorSessionEvents() async {
        for await event in arkitSession.events {
            switch event {
            case .dataProviderStateChanged(_, let newState, let error):
                switch newState {
                case .initialized:
                    break
                case .running:
                    break
                case .paused:
                    break
                case .stopped:
                    if let error {
                        print("An error occurred: \(error)")
                        providersStoppedWithError = true
                    }
                @unknown default:
                    break
                }
            case .authorizationChanged(let type, let status):
                print("Authorization type \(type) changed to \(status)")
                if type == .worldSensing {
                    worldSensingAuthorizationStatus = status
                }
            default:
                print("An unknown event occured \(event)")
            }
        }
    }
    
    // MARK: Object Tracking
    let referenceObjectLoader = ReferenceObjectLoader()
    var objectTracking: ObjectTrackingProvider? = nil

    // MARK: - Xcode Previews

    fileprivate var previewPlacementManager: PlacementManager? = nil

    /// An initial app state for previews in Xcode.
    @MainActor
    static func previewAppState(immersiveSpaceOpened: Bool = false, selectedIndex: Int? = nil) -> AppState {
        let state = AppState()

        state.setPlaceableObjects([previewObject(named: "White sphere"),
                                   previewObject(named: "Red cube"),
                                   previewObject(named: "Blue cylinder"),
                                   previewObject(named: "kucukaraba")])

        if let selectedIndex, selectedIndex < state.modelDescriptors.count {
            state.selectedFileName = state.modelDescriptors[selectedIndex].fileName
        }

        if immersiveSpaceOpened {
            state.previewPlacementManager = PlacementManager()
            state.placementManager = state.previewPlacementManager
        }

        return state
    }
    
    @MainActor
    private static func previewObject(named fileName: String) -> PlaceableObject {
        return PlaceableObject(descriptor: ModelDescriptor(fileName: fileName),
                               renderContent: ModelEntity(),
                               previewEntity: ModelEntity())
    }
}
