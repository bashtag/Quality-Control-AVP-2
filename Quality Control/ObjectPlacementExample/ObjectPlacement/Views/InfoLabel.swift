/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that describes the current app state.
*/

import SwiftUI

struct InfoLabel: View {
    let appState: AppState
    
    var body: some View {
        Text(infoMessage)
            .font(.subheadline)
            .multilineTextAlignment(.center)
    }

    var infoMessage: String {
        if !appState.allRequiredProvidersAreSupported {
            return "This app requires functionality that isn’t supported in Simulator."
        } else if !appState.allRequiredAuthorizationsAreGranted {
            return "This app is missing necessary authorizations. You can change this in Settings > Privacy & Security."
        } else {
            return "Place objects, check their quality, and create detailed reports, ensuring accurate and efficient quality control."
        }
    }
}

#Preview(windowStyle: .plain) {
    InfoLabel(appState: AppState.previewAppState())
        .frame(width: 300)
        .padding(.horizontal, 40.0)
        .padding(.vertical, 20.0)
        .glassBackgroundEffect()
}
