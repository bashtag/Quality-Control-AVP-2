/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The view model for the immersive space.
*/

import Foundation
import ARKit
import RealityKit
import QuartzCore
import SwiftUI

@Observable
final class PlacementManager {
    
    private let worldTracking = WorldTrackingProvider()
    private let planeDetection = PlaneDetectionProvider()
    
    private var planeAnchorHandler: PlaneAnchorHandler
    private var persistenceManager: PersistenceManager
    
    // DEBUG
    private var isSessionRunning: Bool = false // Tracks session state
    private var inspectionPoints: [Entity] = [] // Hold references to the points
    var countButton: Entity?
    var descriptionButton: Entity?
    var yesNoButton: Entity?
    
    enum InspectionPointType: String {
        case forCount = "InspectionPointForCount"
        case forDescription = "InspectionPointForDescription"
        case forYesNoQuestion = "InspectionPointForYesNoQuestion"
    }
    
    @Observable
    final class AnnotationModel: Identifiable {
        let id: String
        var title: String
        var description: String
        var worldPosition: SIMD3<Float>
        var localPosition: SIMD3<Float>
        var isExpanded: Bool
        var yesNoAnswer: Bool?

        init(
            id: String,
            title: String,
            description: String,
            worldPosition: SIMD3<Float>,
            localPosition: SIMD3<Float>,
            isExpanded: Bool = false,
            yesNoAnswer: Bool? = nil  // ← Default nil
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.worldPosition = worldPosition
            self.localPosition = localPosition
            self.isExpanded = isExpanded
            self.yesNoAnswer = yesNoAnswer
        }
        
        func update(title: String, description: String, yesNoAnswer: Bool? = nil) {
            self.title = title
            self.description = description
            self.yesNoAnswer = yesNoAnswer
        }
    }
    
    var appState: AppState? = nil {
        didSet {
            persistenceManager.placeableObjectsByFileName = appState?.placeableObjectsByFileName ?? [:]
        }
    }

    private var currentDrag: DragState? = nil {
        didSet {
            placementState.dragInProgress = currentDrag != nil
        }
    }
    
    var placementState = PlacementState()

    var rootEntity: Entity
    
    private let deviceLocation: Entity
    private let raycastOrigin: Entity
    private let placementLocation: Entity
    private weak var placementTooltip: Entity? = nil
    weak var dragTooltip: Entity? = nil
    weak var deleteButton: Entity? = nil
    
    // Place objects on planes with a small gap.
    static private let placedObjectsOffsetOnPlanes: Float = 0.01
    
    // Snap dragged objects to a nearby horizontal plane within +/- 4 centimeters.
    static private let snapToPlaneDistanceForDraggedObjects: Float = 0.04
    
    @MainActor
    init() {
        let root = Entity()
        rootEntity = root
        placementLocation = Entity()
        deviceLocation = Entity()
        raycastOrigin = Entity()
        
        planeAnchorHandler = PlaneAnchorHandler(rootEntity: root)
        persistenceManager = PersistenceManager(worldTracking: worldTracking, rootEntity: root)
        persistenceManager.loadPersistedObjects()
        
        rootEntity.addChild(placementLocation)
        
        deviceLocation.addChild(raycastOrigin)
        
        // Angle raycasts 15 degrees down.
        let raycastDownwardAngle = 15.0 * (Float.pi / 180)
        raycastOrigin.orientation = simd_quatf(angle: -raycastDownwardAngle, axis: [1.0, 0.0, 0.0])
    }
    
    func saveWorldAnchorsObjectsMapToDisk() {
        persistenceManager.saveWorldAnchorsObjectsMapToDisk()
    }
    
    @MainActor
    func addPlacementTooltip(_ tooltip: Entity) {
        placementTooltip = tooltip
        tooltip.name = "tooltip"
        // Add a tooltip 10 centimeters in front of the placement location to give
        // users feedback about why they can’t currently place an object.
        placementLocation.addChild(tooltip)
        tooltip.position = [0.0, 0.05, 0.2]
        
        for child in placementLocation.children {
            print("Child in placement tooltip name: \(child.name)")
        }
        print("end debug")
    }
    

    @MainActor
    func generateInspectionPoints(for object: PlacedObject) {
        // Get inspection points for the specific object name
        let loader = InspectionPointLoader()
        let inspectionPointsData = loader.getInspectionPoints(for: object.fileName) // Retrieve inspection points

        // Get the object's transform matrix for conversion
        let objectTransform = object.transformMatrix(relativeTo: nil)

        for (index, (inspectionType, inspectionPoint)) in inspectionPointsData.enumerated() {
            // Transform inspection point coordinates (cm) to ARKit coordinates (meters)
            let transformedCoordinate = objectTransform.transformPoint(inspectionPoint.position / 100.0) // Convert cm to meters

            // Determine the button type based on the inspection type
            let buttonEntity: Entity
            switch inspectionType {
            case .forCount:
                guard let countButton else { continue }
                buttonEntity = countButton
            case .forDescription:
                guard let descriptionButton else { continue }
                buttonEntity = descriptionButton
            case .forYesNoQuestion:
                guard let yesNoButton else { continue }
                buttonEntity = yesNoButton
            default:
                print("Unknown inspection type: \(inspectionType)")
                continue
            }

            // Configure the button's position and scale relative to the object
            buttonEntity.position = transformedCoordinate
            buttonEntity.scale = [1 / object.scale.x, 1 / object.scale.y, 1 / object.scale.z] // Scale relative to the object
            buttonEntity.name = "\(object.name)_InspectionButton\(index)"

            // Attach the button to the object's UI origin
            rootEntity.addChild(buttonEntity)

            // Store the button in the inspectionPoints array
            inspectionPoints.append(buttonEntity)

            print("Added \(inspectionType) button: \(buttonEntity.name) at \(buttonEntity.position)")
        }
    }

    func removeInspectionPoints() {
            for point in inspectionPoints {
                point.removeFromParent()
            }
            inspectionPoints.removeAll()
            print("Removed all inspection points.")
        }
    // DEBUG
    @MainActor
    func handleInspectionPointTap(type: InspectionPointType, navigationPath: Binding<[String]>) {
        // Update state and navigate based on type
        appState?.highlightedPoint = type
        appState?.isInspectionDetailsOpen = true
        
        print("Tapped on inspection point: \(type.rawValue)")
    }

    
    // DEBUG
    @MainActor
    func removeHighlightedObject() async {
        guard let highlightedObject = placementState.highlightedObject else { return }

        await persistenceManager.removeObject(highlightedObject)
        placementState.highlightedObject = nil

        // If the removed object is the placed object, reset the state.
        if placementState.placedObject === highlightedObject {
            placementState.placedObject = nil
            placementState.userPlacedAnObject = false
        }
    }

    // DEBUG
    @MainActor
    func removeAllPlacedObjects() async {
        let inputTime = Date().timeIntervalSince1970

        await persistenceManager.removeAllPlacedObjects()

        // Reset placement state after removing all objects.
        placementState.placedObject = nil
        placementState.userPlacedAnObject = false
        // DEBUG
        appState?.inspectionPoints.removeAll()
        
        // reset tracking state
        lastObjectTrackingAnchor = nil
        doesPlacedObjectHaveReferenceObject = false
        
        // annotations
        appState?.placementManager?.annotations.removeAll()
        
        let outputTime = Date().timeIntervalSince1970
            let latency = outputTime - inputTime
            print("Latency in remove placed object: \(latency) seconds")
    }

    
//    DEBUG
    @MainActor
    func runARKitSession() async {
        // DEBUG
        if (isSessionRunning)
        {
            print("ARKit session is already running.")
            return
        }
        
        let referenceObjects = appState?.referenceObjectLoader.enabledReferenceObjects ?? []
        
        if referenceObjects.isEmpty {
            print("Reference objects empyt")
        }
        else {
            print("Reference objects not empty and \(referenceObjects[0])")
        }
        
        let objectTracking = ObjectTrackingProvider(referenceObjects: referenceObjects)
        
        do {
            try await appState!.arkitSession.run([objectTracking, worldTracking, planeDetection])
//            try await appState!.arkitSession.run([objectTracking])

            
            isSessionRunning = true
        } catch {
            print("Failed to run ARKit session: \(error.localizedDescription)")
        }
        appState?.objectTracking = objectTracking
    }


    @MainActor
    func collisionBegan(_ event: CollisionEvents.Began) {
        guard let selectedObject = placementState.selectedObject else { return }
        guard selectedObject.matchesCollisionEvent(event: event) else { return }

        placementState.activeCollisions += 1
    }
    
    @MainActor
    func collisionEnded(_ event: CollisionEvents.Ended) {
        guard let selectedObject = placementState.selectedObject else { return }
        guard selectedObject.matchesCollisionEvent(event: event) else { return }
        guard placementState.activeCollisions > 0 else {
            print("Received a collision ended event without a corresponding collision start event.")
            return
        }

        placementState.activeCollisions -= 1
    }
    
    @MainActor
    func select(_ object: PlaceableObject?) {
        if let oldSelection = placementState.selectedObject {
            // Remove the current preview entity.
            placementLocation.removeChild(oldSelection.previewEntity)

            // Handle deselection. Selecting the same object again in the app deselects it.
            if oldSelection.descriptor.fileName == object?.descriptor.fileName {
                select(nil)
                return
            }
        }
             
        // Update state.
        placementState.selectedObject = object
        appState?.selectedFileName = object?.descriptor.fileName
        
        if let object {
            // Add new preview entity.
            placementLocation.addChild(object.previewEntity)
            for child in placementLocation.children {
                print("Child name: \(child.name)")
            }
        }
    }
    
    @MainActor
    func processWorldAnchorUpdates() async {
        for await anchorUpdate in worldTracking.anchorUpdates {
            persistenceManager.process(anchorUpdate)
        }
    }
    
    @MainActor
    func processDeviceAnchorUpdates() async {
        await run(function: self.queryAndProcessLatestDeviceAnchor, withFrequency: 90)
    }
    
    @MainActor
    private func queryAndProcessLatestDeviceAnchor() async {
        // Device anchors are only available when the provider is running.
        guard worldTracking.state == .running else { return }
        
        let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())

        placementState.deviceAnchorPresent = deviceAnchor != nil
        placementState.planeAnchorsPresent = !planeAnchorHandler.planeAnchors.isEmpty
        placementState.selectedObject?.previewEntity.isEnabled = placementState.shouldShowPreview
        
        guard let deviceAnchor, deviceAnchor.isTracked else { return }
        
        await updateUserFacingUIOrientations(deviceAnchor)
        await checkWhichObjectDeviceIsPointingAt(deviceAnchor)
        await updatePlacementLocation(deviceAnchor)
    }
    
    
    @MainActor
    private func updateUserFacingUIOrientations(_ deviceAnchor: DeviceAnchor) async {
        // 1. Orient the front side of the highlighted object’s UI to face the user.
        if let uiOrigin = placementState.highlightedObject?.uiOrigin {
            // Set the UI to face the user (on the y-axis only).ğƒ
            uiOrigin.look(at: deviceAnchor.originFromAnchorTransform.translation)
            let uiRotationOnYAxis = uiOrigin.transformMatrix(relativeTo: nil).gravityAligned.rotation
            uiOrigin.setOrientation(uiRotationOnYAxis, relativeTo: nil)
        }
        
        // 2. Orient each UI element to face the user.
        for entity in [placementTooltip, dragTooltip, deleteButton] {
            if let entity {
                entity.look(at: deviceAnchor.originFromAnchorTransform.translation)
            }
        }
        
        // 🔄 Preview Annotation Orientation
       if let preview = previewAttachmentEntity {
           preview.look(at: deviceAnchor.originFromAnchorTransform.translation)
//           let upright = preview.transformMatrix(relativeTo: nil).gravityAligne-
       }
        
        // annotation orientation
        for annotation in annotations {
            if let anchor = rootEntity.findEntity(named: annotation.id),
               let holder = anchor.findEntity(named: "\(annotation.id)_holder") {

//                let anchorWorldPos = anchor.position(relativeTo: nil)
//                let holderWorldPos = holder.position(relativeTo: nil)
//                let devicePos = deviceAnchor.originFromAnchorTransform.translation
//
//                print("\n--- Annotation Debug: \(annotation.id) ---")
//                print("Anchor Position (world): \(anchorWorldPos)")
//                print("Holder Position (world): \(holderWorldPos)")
//                print("Device Position (camera world): \(devicePos)")
//                print("Vector Anchor → Device: \(devicePos - anchorWorldPos)")
//                print("Vector Holder → Device: \(devicePos - holderWorldPos)")
//                
//                let anchorForwardVec = normalize(devicePos - anchorWorldPos)
//                let holderForwardVec = normalize(devicePos - holderWorldPos)
//                print("Anchor Look Direction: \(anchorForwardVec)")
//                print("Holder Look Direction: \(holderForwardVec)")

                // Apply look-at logic
//                anchor.look(at: deviceAnchor.originFromAnchorTransform.translation)
//                let anchorMat = anchor.transformMatrix(relativeTo: nil)
//                let anchorRot = anchorMat.gravityAligned.rotation
////                print("Anchor gravity-aligned Y-rotation: \(anchorRot)")
//                anchor.setOrientation(anchorRot, relativeTo: nil)

                holder.look(at: deviceAnchor.originFromAnchorTransform.translation)

//                // Optional: Use full basis debug
//                let up = SIMD3<Float>(0, 1, 0)
//                let forward = normalize(devicePos - holderWorldPos)
//                let right = normalize(cross(up, forward))
//                let adjustedUp = normalize(cross(forward, right))
//                let rotMatrix = float3x3(columns: (right, adjustedUp, forward))
//                let debugQuat = simd_quatf(rotMatrix)

//                print("Holder Right: \(right)")
//                print("Holder Up (adjusted): \(adjustedUp)")
//                print("Holder Forward: \(forward)")
//                print("Holder Orientation (from matrix): \(debugQuat)")

                // You may optionally use this orientation if .look(at:) isn’t behaving
                // holder.orientation = debugQuat

//                print("--- End of Annotation Debug ---\n")
            } else {
//                print("⚠️ Could not find anchor or holder for annotation: \(annotation.id)")
            }
            
        }
    }
    
    @MainActor
    private func updatePlacementLocation(_ deviceAnchor: DeviceAnchor) async {
//        let inputTime = Date().timeIntervalSince1970

        
        deviceLocation.transform = Transform(matrix: deviceAnchor.originFromAnchorTransform)
        let originFromUprightDeviceAnchorTransform = deviceAnchor.originFromAnchorTransform.gravityAligned
        
        // Determine a placement location on planes in front of the device by casting a ray.
        
        // Cast the ray from the device origin.
        let origin: SIMD3<Float> = raycastOrigin.transformMatrix(relativeTo: nil).translation
    
        // Cast the ray along the negative z-axis of the device anchor, but with a slight downward angle.
        // (The downward angle is configurable using the `raycastOrigin` orientation.)
        let direction: SIMD3<Float> = -raycastOrigin.transformMatrix(relativeTo: nil).zAxis
        
        // Only consider raycast results that are within 0.2 to 3 meters from the device.
        let minDistance: Float = 0.2
        let maxDistance: Float = 3
        
        // Only raycast against horizontal planes.
        let collisionMask = PlaneAnchor.allPlanesCollisionGroup

        var originFromPointOnPlaneTransform: float4x4? = nil
        if let result = rootEntity.scene?.raycast(origin: origin, direction: direction, length: maxDistance, query: .nearest, mask: collisionMask)
                                                  .first, result.distance > minDistance {
            if result.entity.components[CollisionComponent.self]?.filter.group != PlaneAnchor.verticalCollisionGroup {
                // If the raycast hit a horizontal plane, use that result with a small, fixed offset.
                originFromPointOnPlaneTransform = originFromUprightDeviceAnchorTransform
                originFromPointOnPlaneTransform?.translation = result.position + [0.0, PlacementManager.placedObjectsOffsetOnPlanes, 0.0]
            }
        }
        // DEBUG
        
//        if let originFromPointOnPlaneTransform {
//            // If a placement location is determined, set the transform and ensure the prefab is visible.
//            placementLocation.transform = Transform(matrix: originFromPointOnPlaneTransform)
//            placementLocation.isEnabled = true  // Make the prefab visible
//            placementState.planeToProjectOnFound = true
//        } else {
//            // If no placement location can be determined, hide the prefab but keep the warning visible.
//            placementLocation.isEnabled = false // Hide the prefab
//            placementState.planeToProjectOnFound = false
//        }
        
//        // Ensure the warning is always visible
//        placementTooltip?.isEnabled = true
        // END DEBUG
        
        
        if let originFromPointOnPlaneTransform {
            placementLocation.transform = Transform(matrix: originFromPointOnPlaneTransform)
            placementState.planeToProjectOnFound = true
            
            
            if placementLocation.children.count > 1
            {
                for child in placementLocation.children
                {
                    if child.name != "tooltip"
                    {
                        if placementState.placedObject == nil {
                            child.isEnabled = true
                        }
                        else if placementState.placedObject != nil
                        {
                            child.isEnabled = false
                        }
                    }
                }
               
            }
            
        } else {
            // If no placement location can be determined, position the preview 50 centimeters in front of the device.
            let distanceFromDeviceAnchor: Float = 0.7
            let downwardsOffset: Float = -0.07
            var uprightDeviceAnchorFromOffsetTransform = matrix_identity_float4x4
            uprightDeviceAnchorFromOffsetTransform.translation = [0, -downwardsOffset, -distanceFromDeviceAnchor]
            let originFromOffsetTransform = originFromUprightDeviceAnchorTransform * uprightDeviceAnchorFromOffsetTransform

            placementLocation.transform = Transform(matrix: originFromOffsetTransform)
            placementState.planeToProjectOnFound = false
            
            // Hide the second child if it exists
            if placementLocation.children.count > 1 {
                for child in placementLocation.children
                {
                    if child.name != "tooltip"
                    {
                        child.isEnabled = false
                    }
                }
            }
        }
        
//        if let originFromPointOnPlaneTransform {
//            placementLocation.transform = Transform(matrix: originFromPointOnPlaneTransform)
//            placementState.planeToProjectOnFound = true
//        } else {
//            // If no placement location can be determined, position the preview 50 centimeters in front of the device.
//            let distanceFromDeviceAnchor: Float = 0.5
//            let downwardsOffset: Float = 0.3
//            var uprightDeviceAnchorFromOffsetTransform = matrix_identity_float4x4
//            uprightDeviceAnchorFromOffsetTransform.translation = [0, -downwardsOffset, -distanceFromDeviceAnchor]
//            let originFromOffsetTransform = originFromUprightDeviceAnchorTransform * uprightDeviceAnchorFromOffsetTransform
//
//            placementLocation.transform = Transform(matrix: originFromOffsetTransform)
//            placementState.planeToProjectOnFound = false
//        }
//        let outputTime = Date().timeIntervalSince1970
//            let latency = outputTime - inputTime
//            print("Latency in update placement: \(latency) seconds")
    }
    
    @MainActor
    private func checkWhichObjectDeviceIsPointingAt(_ deviceAnchor: DeviceAnchor) async {
        let origin: SIMD3<Float> = raycastOrigin.transformMatrix(relativeTo: nil).translation
        let direction: SIMD3<Float> = -raycastOrigin.transformMatrix(relativeTo: nil).zAxis
        let collisionMask = PlacedObject.collisionGroup
        
        if let result = rootEntity.scene?.raycast(origin: origin, direction: direction, query: .nearest, mask: collisionMask).first {
            if let pointedAtObject = persistenceManager.object(for: result.entity) {
                setHighlightedObject(pointedAtObject)
                
                // changed here
                lastHitLocation = result.position // Store the hit location
                
//                // Show annotation preview if in annotation mode
//                if appState?.viewMode == .annotation {
//                    showAnnotationPreview()
//                }
                
                if appState?.viewMode == .addAnnotation {
//                    print("hit location updated", result.position)
                    
                    await showAnnotationPreview(title: "Checkpoint", description: "Possible issue area.")
                    
                }



            } else {
                setHighlightedObject(nil)
                
                lastHitLocation = nil

            }
        } else {
            setHighlightedObject(nil)
            
            lastHitLocation = nil
        }
    }
    
    private var lastHitLocation: SIMD3<Float>? = nil
    var focusedAnnotationId: String? = nil
    
    @MainActor
    func focusAnnotation(withTitle title: String) {
        guard let annotation = annotations.first(where: { $0.title == title }) else {
            print("⚠️ Annotation not found for focus: \(title)")
            return
        }

        focusedAnnotationId = annotation.id
        
        // Optionally highlight the annotation in the AR scene
        print("🔍 Focusing on '\(annotation.title)' at \(annotation.worldPosition)")

//        // You could add a visual indicator here (e.g., highlight or pulse effect)
//        let highlightEntity = ModelEntity(mesh: .generateSphere(radius: 0.01),
//                                          materials: [SimpleMaterial(color: .yellow, isMetallic: false)])
//        highlightEntity.name = "highlight_\(annotation.id)"
//        highlightEntity.position = .zero
//
//        let anchorEntity = AnchorEntity(world: annotation.worldPosition)
//        anchorEntity.addChild(highlightEntity)
//        rootEntity.addChild(anchorEntity)
//
//        // Auto-remove after a short duration (like a ping effect)
//        Task {
//            try? await Task.sleep(nanoseconds: 2_000_000_000)
//            anchorEntity.removeFromParent()
//        }
    }

    @MainActor
    func changeAnnotation(withTitle title: String) {
        guard let annotation = annotations.first(where: { $0.title == title }) else {
            print("⚠️ Annotation not found for change: \(title)")
            return
        }

        // You could store it in a selectedAnnotation property, or open a modal
        print("✏️ Requested change for '\(annotation.title)'")
        
        // Example: mark it expanded in-place (if you later bind this flag to a view)
        annotation.isExpanded.toggle()
    }
    
    @MainActor
    func removeAnnotation(at index: String)
    {
        guard let annotation = annotations.first(where: { $0.id == index }) else {
            print("⚠️ Annotation not found for removal: \(index)")
            return
        }
        
        annotations.removeAll { $0.id == index }
        
        print("🗑️ Removed annotation '\(annotation.title)'")
    }
    
    @MainActor
    func removeFocusedAnnotation() {
        removeAnnotation(at: focusedAnnotationId ?? "")
    }

    @MainActor
    func removeAnnotation(withTitle title: String) {
        guard let index = annotations.firstIndex(where: { $0.title == title }) else {
            print("⚠️ Annotation not found for removal: \(title)")
            return
        }

        let annotation = annotations[index]
        annotations.remove(at: index)

        print("🗑️ Removed annotation '\(annotation.title)'")

        // Remove associated anchor entity
        if let anchorEntity = rootEntity.children.first(where: { $0.name == annotation.id }) {
            anchorEntity.removeFromParent()
            print("🔧 Removed anchor entity for annotation \(annotation.id)")
        } else {
            print("⚠️ No matching anchor entity found in scene for removal")
        }
    }
    
    var annotationTitles: [String] {
        annotations.map { $0.title }
    }
    
    var annotations: [AnnotationModel] = []
    var previewAnnotation: AnnotationModel? = nil
    var previewAttachmentEntity: Entity? = nil

    private let annotationOffsetDistance: Float = 0.05
    
    @MainActor
    func showAnnotationPreview(title: String = "Defect", description: String = "Check area.") {
        guard let object = placementState.highlightedObject,
              let hitLocation = lastHitLocation else { return }

        // 1) convert the world hit into local coordinates
        let localPos = object.convert(position: hitLocation, from: nil)
        // 2) compute a unit ray from object center → hit point
        let outward = normalize(localPos)
        // 3) push the preview out along that ray
        let offsetLocalPos = localPos + outward * annotationOffsetDistance

        if let existing = previewAttachmentEntity {
            existing.position = offsetLocalPos
        } else {
            let previewEntity = Entity()
            previewEntity.name = "preview_annotation"
            previewEntity.position = offsetLocalPos
            previewEntity.generateCollisionShapes(recursive: true)
            object.addChild(previewEntity)
            previewAttachmentEntity = previewEntity
        }

        previewAnnotation = AnnotationModel(
            id: "preview_annotation",
            title: title,
            description: description,
            worldPosition: hitLocation,
            localPosition: localPos
        )
    }

    @MainActor
    func clearPreviewAnnotation() {
        // Remove the preview entity from the scene
        previewAttachmentEntity?.removeFromParent()
        previewAttachmentEntity = nil
        
        // Drop the model data
        previewAnnotation = nil
    }
    
    // 100 annot success criteria
    let successCriteria100Annot = false
    private var usedRandomNumbers: Set<Int> = []

    @MainActor
    func addAnnotation() {
        guard let preview = previewAnnotation,
              let object = placementState.highlightedObject else {
            print("🔴 Failed to add annotation: Missing preview or highlighted object.")
            return
        }

        let id = UUID().uuidString
        
        if successCriteria100Annot == true {
            if usedRandomNumbers.count >= 100 {
                print("All numbers 1–100 have been used.")
            } else {
                var random: Int
                repeat {
                    random = Int.random(in: 1...100) // includes 100, excludes 0 ✅
                } while usedRandomNumbers.contains(random)

                usedRandomNumbers.insert(random)
                preview.title = "\(random)"
            }
        }
        
        annotations.append(.init(
            id: id,
            title: preview.title,
            description: preview.description,
            worldPosition: preview.worldPosition,
            localPosition: preview.localPosition
        ))

//        print("\n🟢 --- Adding Annotation \(id) ---")
//        print("📌 Preview world position: \(preview.worldPosition)")

        // Anchor at the original hit point
        let anchorEntity = AnchorEntity()
        anchorEntity.transform.translation = preview.worldPosition
        anchorEntity.name = id
//        print("📍 Anchor world position (initial): \(anchorEntity.transform.translation)")

        // Compute ray from object center → hit, in world space
        let objectWorldPos = object.transformMatrix(relativeTo: nil).translation
        let outwardWorld = normalize(preview.worldPosition - objectWorldPos)
//        print("🧭 Object world position: \(objectWorldPos)")
//        print("➡️  Outward vector (object → hit): \(outwardWorld)")

        let holder = Entity()
        holder.name = "\(id)_holder"
        holder.position = outwardWorld * annotationOffsetDistance
//        print("📦 Holder local offset from anchor: \(holder.position)")
        
        // Add a debug arrow (optional visual)
//        let debugArrow = ModelEntity(mesh: .generateBox(size: [0.01, 0.01, 0.05]),
//                                     materials: [SimpleMaterial(color: .red, isMetallic: false)])
//        debugArrow.position = .zero
//        debugArrow.look(at: outwardWorld)
//        holder.addChild(debugArrow)
//        anchorEntity.addChild(debugArrow)
        anchorEntity.addChild(holder)
        rootEntity.addChild(anchorEntity)

//        print("✅ Annotation added to rootEntity.")
//        print("🟢 --- End Annotation \(id) ---\n")

        // cleanup
        previewAttachmentEntity?.removeFromParent()
        previewAnnotation = nil
        previewAttachmentEntity = nil
        
        // add view
        appState?.placementManager?.focusedAnnotationId = id
        
        if successCriteria100Annot == false
        {
            appState?.isAnnotationAdded = true
        }
    }

    @MainActor
    func updateFocusedAnnotation(title: String, description: String, yesNoAnswer: Bool? = nil) {
        guard let id = focusedAnnotationId,
              let annotation = annotations.first(where: { $0.id == id }) else {
            print("⚠️ No annotation found for update")
            return
        }
        annotation.title = title
        annotation.description = description
        annotation.yesNoAnswer = yesNoAnswer
    }


    @MainActor
    func getAnnotationTitleAndDescription(forAnnotationId id: String) -> (title: String, description: String)? {
        guard let annotation = annotations.first(where: { $0.id == id }) else { return nil }
        return (title: annotation.title, description: annotation.description)
    }

    @MainActor
    func getFocusedAnnotationInfo() -> (title: String, description: String, yesNoAnswer: Bool?)? {
        guard let id = focusedAnnotationId,
              let annotation = annotations.first(where: { $0.id == id }) else {
            return nil
        }
        return (annotation.title, annotation.description, annotation.yesNoAnswer)
    }

    
    @MainActor
    func hideAnnotations(animated: Bool = true) {
        for annotation in annotations {
            if let anchorEntity = rootEntity.findEntity(named: annotation.id) {
                if animated {
                    var transform = anchorEntity.transform
                    transform.scale = SIMD3<Float>(0.01, 0.01, 0.01)
                    anchorEntity.move(to: transform, relativeTo: anchorEntity.parent, duration: 0.3)
                    
                    // Hide after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        anchorEntity.isEnabled = false
                    }
                } else {
                    anchorEntity.isEnabled = false
                }
            }
        }
    }

    @MainActor
    func showAnnotations(animated: Bool = true) {
        for annotation in annotations {
            if let anchorEntity = rootEntity.findEntity(named: annotation.id) {
                anchorEntity.isEnabled = true
                
                if animated {
                    // Start from tiny scale
                    anchorEntity.transform.scale = SIMD3<Float>(0.01, 0.01, 0.01)
                    
                    // Animate to normal scale
                    var transform = anchorEntity.transform
                    transform.scale = SIMD3<Float>(1, 1, 1)
                    anchorEntity.move(to: transform, relativeTo: anchorEntity.parent, duration: 0.3)
                }
            }
        }
    }
    
    @MainActor
    func setHighlightedObject(_ objectToHighlight: PlacedObject?) {
        guard placementState.highlightedObject != objectToHighlight else {
            return
        }
        placementState.highlightedObject = objectToHighlight

        // Detach UI from the previously highlighted object.
        guard let deleteButton, let dragTooltip else { return }
        deleteButton.removeFromParent()
        dragTooltip.removeFromParent()

        guard let objectToHighlight else { return }

        // Position and attach the UI to the newly highlighted object.
        let extents = objectToHighlight.extents
        print("extents : \(extents)")
        let topLeftCorner: SIMD3<Float> = [-extents.x / 2, (extents.y / 2) + 0.02, 0]
        let frontBottomCenter: SIMD3<Float> = [0, (-extents.y / 2) + 0.04, extents.z / 2 + 0.04]
        deleteButton.position = topLeftCorner
        dragTooltip.position = frontBottomCenter

        objectToHighlight.uiOrigin.addChild(deleteButton)
        deleteButton.scale = 1 / objectToHighlight.scale
        objectToHighlight.uiOrigin.addChild(dragTooltip)
        dragTooltip.scale = 1 / objectToHighlight.scale
    }

//    func removeAllPlacedObjects() async {
//        await persistenceManager.removeAllPlacedObjects()
//    }
    
    func processPlaneDetectionUpdates() async {
        for await anchorUpdate in planeDetection.anchorUpdates {
            await planeAnchorHandler.process(anchorUpdate)
        }

    }
    
    @MainActor
    func snapButtonTapped() {
        guard let placedObject = placementState.placedObject else { return }
        guard let anchorMatrix = lastObjectTrackingAnchor else { return }
        
        placedObject.stopAllAnimations()
//        placedObject.transform = Transform(matrix: anchorMatrix)
//        placedObject.transform.matrix = anchorMatrix
        
        let position = SIMD3<Float>(
            anchorMatrix.columns.3.x,
            anchorMatrix.columns.3.y,
            anchorMatrix.columns.3.z
        )
        
        // Extract rotation as quaternion from the matrix
        let rotation = simd_quatf(anchorMatrix)
        
        // Extract scale (if needed)
        let scaleX = length(SIMD3<Float>(anchorMatrix.columns.0.x, anchorMatrix.columns.0.y, anchorMatrix.columns.0.z))
        let scaleY = length(SIMD3<Float>(anchorMatrix.columns.1.x, anchorMatrix.columns.1.y, anchorMatrix.columns.1.z))
        let scaleZ = length(SIMD3<Float>(anchorMatrix.columns.2.x, anchorMatrix.columns.2.y, anchorMatrix.columns.2.z))
        let scale = SIMD3<Float>(scaleX, scaleY, scaleZ)
        
        // Set the transform components directly
        placedObject.setPosition(position, relativeTo: nil)
        placedObject.setOrientation(rotation, relativeTo: nil)
        placedObject.setScale(scale, relativeTo: nil)
        
        updateAnnotationsForDraggedObject(placedObject)
    }
    
    private var lastObjectTrackingAnchor: simd_float4x4? = nil
    private(set) var doesPlacedObjectHaveReferenceObject: Bool = false

    func processObjectTrackingUpdates() async {
        guard let appState = appState,
              let objectTracking = appState.objectTracking else { return }
        
        for await anchorUpdate in objectTracking.anchorUpdates {
            let anchor = anchorUpdate.anchor
            let id = anchor.id
            var referenceObjectFileName: String?
            
            if let url = anchor.referenceObject.inputFile {
                referenceObjectFileName = url.deletingPathExtension().lastPathComponent
            } else {
                referenceObjectFileName = "Unknown"
            }
            
            if referenceObjectFileName == placementState.placedObject?.fileName {
                if !doesPlacedObjectHaveReferenceObject
                {
                    doesPlacedObjectHaveReferenceObject = true
                }
                
                switch anchorUpdate.event {
                case .added:
                    lastObjectTrackingAnchor = anchor.originFromAnchorTransform
                    
                    if appState.mode == .objectTracking {
                         await snapButtonTapped()
                    }
                case .updated:
                    lastObjectTrackingAnchor = anchor.originFromAnchorTransform
                    if appState.mode == .objectTracking {
                        await snapButtonTapped()
                    }
                case .removed:
                    lastObjectTrackingAnchor = nil
                }
            }
        }
    }
    
    // DEBUG
    @MainActor
    func placeSelectedObject() {
        // Ensure there’s a placeable object and no object is already placed.
        guard let objectToPlace = placementState.objectToPlace, placementState.placedObject == nil else {
            print("An object is already placed. Cannot place another.")
            return
        }

        let object = objectToPlace.materialize()

        object.position = placementLocation.position
        object.orientation = placementLocation.orientation
        
        
        self.setOpacityRecursively(entity: object, opacity: 0.3) // Or your desired opacity

        Task {
            await persistenceManager.attachObjectToWorldAnchor(object)
        }

        placementState.userPlacedAnObject = true
        placementState.placedObject = object // Save the reference to the placed object.
    }
    
    // This preserves textures and only sets opacity!
    private func setOpacityRecursively(entity: Entity, opacity: Float) {
        if let modelEntity = entity as? ModelEntity {
            var newMaterials: [RealityKit.Material] = []
            for material in modelEntity.model?.materials ?? [] {
                if var pbMaterial = material as? PhysicallyBasedMaterial {
                    // Adjust tint (will not affect texture!)
                    pbMaterial.baseColor.tint = pbMaterial.baseColor.tint.withAlphaComponent(Double(opacity))
                    newMaterials.append(pbMaterial)
                } else if var simpleMaterial = material as? SimpleMaterial {
                    var color = simpleMaterial.color
                    color.tint = color.tint.withAlphaComponent(Double(opacity))
                    simpleMaterial.color = color
                    newMaterials.append(simpleMaterial)
                } else {
                    newMaterials.append(material)
                }
            }
            modelEntity.model?.materials = newMaterials
        }
        for child in entity.children {
            setOpacityRecursively(entity: child, opacity: opacity)
        }
    }

    
    private func applyMaterialRecursively(withModel model: Entity, withMaterial material: RealityFoundation.Material){
        if let modelEntity = model as? ModelEntity {
            modelEntity.model?.materials = [material]
        }
        for child in model.children {
            applyMaterialRecursively(withModel: child, withMaterial: material)
        }
    }

    
//    @MainActor
//    func placeSelectedObject() {
//        // Ensure there’s a placeable object.
//        guard let objectToPlace = placementState.objectToPlace else { return }
//
//        let object = objectToPlace.materialize()
//
//        // DEBUG
//        // Remove physics components to disable falling or rotating
////        object.components[PhysicsBodyComponent.self] = nil
////        object.components[CollisionComponent.self] = nil
//
//        object.position = placementLocation.position
//        object.orientation = placementLocation.orientation
//
//        Task {
//            await persistenceManager.attachObjectToWorldAnchor(object)
//        }
//        placementState.userPlacedAnObject = true
//    }
    
    @MainActor
    func checkIfAnchoredObjectsNeedToBeDetached() async {
        // Check whether objects should be detached from their world anchor.
        // This runs at 10 Hz to ensure that objects are quickly detached from their world anchor
        // as soon as they are moved - otherwise a world anchor update could overwrite the
        // object’s position.
        await run(function: persistenceManager.checkIfAnchoredObjectsNeedToBeDetached, withFrequency: 10)
    }
    
    @MainActor
    func checkIfMovingObjectsCanBeAnchored() async {
        // Check whether objects can be reanchored.
        // This runs at 2 Hz - objects should be reanchored eventually but it’s not time critical.
        await run(function: persistenceManager.checkIfMovingObjectsCanBeAnchored, withFrequency: 2)
    }
    
    @MainActor
    func updateDrag(value: EntityTargetValue<DragGesture.Value>) {
        if let currentDrag, currentDrag.draggedObject !== value.entity {
            // Make sure any previous drag ends before starting a new one.
            print("A new drag started but the previous one never ended - ending that one now.")
            endDrag()
        }
        
        // At the start of the drag gesture, remember which object is being manipulated.
        if currentDrag == nil {
            guard let object = persistenceManager.object(for: value.entity) else {
                print("Unable to start drag - failed to identify the dragged object.")
                return
            }
            
            // DEBUG
            object.components[PhysicsBodyComponent.self] = nil

            object.isBeingDragged = true
            currentDrag = DragState(objectToDrag: object)
            placementState.userDraggedAnObject = true
        }
        
        // Update the dragged object’s position.
        if let currentDrag {
            // DEBUG
            
            // preserve the Y location
            let currentY = currentDrag.initialPosition.y
            let newTranslation = value.convert(value.translation3D, from: .local, to: rootEntity)
            var constrainedPosition = SIMD3<Float>(currentDrag.initialPosition.x + newTranslation.x,
                                                   currentY, // Lock Y-coordinate
                                                   currentDrag.initialPosition.z + newTranslation.z)
            currentDrag.draggedObject.position = constrainedPosition
//            currentDrag.draggedObject.position = currentDrag.initialPosition + value.convert(value.translation3D, from: .local, to: rootEntity)

            // If possible, snap the dragged object to a nearby horizontal plane.
//            let maxDistance = PlacementManager.snapToPlaneDistanceForDraggedObjects
//            if let projectedTransform = PlaneProjector.project(point: currentDrag.draggedObject.transform.matrix,
//                                                               ontoHorizontalPlaneIn: planeAnchorHandler.planeAnchors,
//                                                               withMaxDistance: maxDistance) {
//                currentDrag.draggedObject.position = projectedTransform.translation
//            }
        }
    }
    
    @MainActor
    func updateDrag(value: EntityTargetValue<DragGesture.Value>, mode: AppState.InteractionMode) {
            if currentDrag == nil {
                guard let object = placementState.placedObject else {
                    print("No object to drag.")
                    return
                }
                currentDrag = DragState(objectToDrag: object)
                print("Started dragging \(object)")
            }

            guard let currentDrag else { return }

            // Constrain movement based on the selected mode
            let translation = value.translation
            switch mode {
            case .rotation:
                // Rotate the object around the y-axis
                let rotationSpeed: Float = 0.006 // Adjust for desired constant speed

                    // Use the 3D translation to determine rotation direction and intensity
                    let dragDelta = Float(value.translation3D.x) // Use X-axis translation in 3D space
                    let rotationAngle = rotationSpeed * (dragDelta > 0 ? 1.0 : -1.0) // Determine direction

                    let rotationQuat = simd_quatf(angle: rotationAngle, axis: SIMD3<Float>(0, 1, 0)) // Rotate around Y-axis

                    // Apply the rotation to the current orientation
                    let newOrientation = currentDrag.draggedObject.orientation * rotationQuat
                    currentDrag.draggedObject.orientation = newOrientation

//                let rotationAngle = Float(translation.width) * 0.01 // Adjust sensitivity
//                currentDrag.draggedObject.transform.rotation *= simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
//                print("Rotating object by \(rotationAngle) radians.")

            case .forwardBack:
                // Move the object along the z-axis (forward/backward)
                
                let translation3D = value.convert(value.translation3D, from: .local, to: rootEntity)
                
                currentDrag.draggedObject.position.z = currentDrag.initialPosition.z + translation3D.z
                
//                let movement = Float(translation.height) * -0.01 // Adjust sensitivity
//                currentDrag.draggedObject.position.z = currentDrag.initialPosition.z + movement
//                print("Moving object forward/backward by \(movement).")

            case .leftRight:
                // Move the object along the x-axis (left/right)
                
                let translation3D = value.convert(value.translation3D, from: .local, to: rootEntity)
                
                currentDrag.draggedObject.position.x = currentDrag.initialPosition.x + translation3D.x
//                let movement = Float(translation.width) * 0.01 // Adjust sensitivity
//                currentDrag.draggedObject.position.x = currentDrag.initialPosition.x + movement
//                print("Moving object left/right by \(movement).")
            case .objectTracking:
                break
            }
        
        updateAnnotationsForDraggedObject(currentDrag.draggedObject)
        
        }
    
    @MainActor
    func endDrag() {
        guard let currentDrag else { return }
        currentDrag.draggedObject.isBeingDragged = false
        self.currentDrag = nil
    }
    
    @MainActor
    func updateAnnotationsForDraggedObject(_ object: Entity) {
        let objectTransform = object.transformMatrix(relativeTo: nil)
        for annotation in annotations {
            // Convert local position to world position using the updated object transform
            let worldPos = (objectTransform * SIMD4<Float>(annotation.localPosition, 1)).xyz
            annotation.worldPosition = worldPos
            
        }
    }

    
//    @MainActor
//    func pauseARKitSession() async {
//        appState?.arkitSession.stop()
//    }

}

extension PlacementManager {
    /// Run a given function at an approximate frequency.
    ///
    /// > Note: This method doesn’t take into account the time it takes to run the given function itself.
    @MainActor
    func run(function: () async -> Void, withFrequency hz: UInt64) async {
        while true {
            if Task.isCancelled {
                return
            }
            
            // Sleep for 1 s / hz before calling the function.
            let nanoSecondsToSleep: UInt64 = NSEC_PER_SEC / hz
            do {
                try await Task.sleep(nanoseconds: nanoSecondsToSleep)
            } catch {
                // Sleep fails when the Task is cancelled. Exit the loop.
                return
            }
            
            await function()
        }
    }
}
