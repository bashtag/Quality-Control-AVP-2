/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app’s entry point.
*/

import SwiftUI

private enum UIIdentifier {
    static let immersiveSpace = "Object Placement"
}

@main
@MainActor
struct ObjectPlacementApp: App {
    @State private var appState = AppState()
    @State private var modelLoader = ModelLoader()
    @State private var navigationPath: [String] = []
    
    static var appShortcutsProvider = AnnotationShortcuts.self
    
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.scenePhase) private var scenePhase

    var body: some SwiftUI.Scene {
        WindowGroup {
            HomeView(
                appState: appState,
                modelLoader: modelLoader,
                immersiveSpaceIdentifier: UIIdentifier.immersiveSpace,
                navigationPath: navigationPath
            )
                .task {
                    if appState.allRequiredProvidersAreSupported {
                        await appState.referenceObjectLoader.loadBuiltInReferenceObjects()
                    }
                    await modelLoader.loadObjects()
                    appState.setPlaceableObjects(modelLoader.placeableObjects)
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.plain)
        
        ImmersiveSpace(id: UIIdentifier.immersiveSpace) {
            ObjectPlacementRealityView(appState: appState, navigationPath: navigationPath)
        }
        .onChange(of: scenePhase, initial: true) {
            if scenePhase != .active {
                // Leave the immersive space when the user dismisses the app.
                if appState.immersiveSpaceOpened {
                    Task {
                        await dismissImmersiveSpace()
                        appState.didLeaveImmersiveSpace()
                    }
                }
            }
        }
    }
}
