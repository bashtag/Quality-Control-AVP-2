//
//  SwiftUIView.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 11.01.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct PositionView: View {
    var appState: AppState
    
//    enum Mode: String {
//        case rotation = "Rotation"
//        case forwardBack = "Forward-Back"
//        case leftRight = "Left-Right"
//    }

    var body: some View {
        VStack {
            Text("Adjust Position")
                .font(.title)
                .padding()

            Text("Current Mode: \(appState.mode?.rawValue ?? "None")")
                .font(.headline)
                .padding()
            
            let disabled = appState.mode == .objectTracking

            // Three buttons for modes
            HStack(spacing: 20) {
//                Button(action: { toggleMode(AppState.InteractionMode.rotation) }) {
//                    Text("Rotation")
//                        .padding()
//                        .frame(maxWidth: .infinity)
//                        .background(appState.mode == .rotation ? Color.blue : Color.gray.opacity(0.2))
//                        .cornerRadius(10)
//                        .foregroundColor(.white)
//                }
                
//                Button(action: { toggleMode(AppState.InteractionMode.forwardBack) }) {
//                    Text("Forward-Back")
//                        .padding()
//                        .frame(maxWidth: .infinity)
//                        .background(appState.mode == .forwardBack ? Color.blue : Color.gray.opacity(0.2))
//                        .cornerRadius(10)
//                        .foregroundColor(.white)
//                }
//
//                Button(action: { toggleMode(AppState.InteractionMode.leftRight) }) {
//                    Text("Left-Right")
//                        .padding()
//                        .frame(maxWidth: .infinity)
//                        .background(appState.mode == .leftRight ? Color.blue : Color.gray.opacity(0.2))
//                        .cornerRadius(10)
//                        .foregroundColor(.white)
//                }
                
                Button(action: { toggleMode(.rotation) }) {
                    Text("Rotation")
                }
                .buttonStyle(ToggleModeButtonStyle(isActive: appState.mode == .rotation))

                Button(action: { toggleMode(.forwardBack) }) {
                    Text("Forward-Back")
                }
                .buttonStyle(ToggleModeButtonStyle(isActive: appState.mode == .forwardBack))

                Button(action: { toggleMode(.leftRight) }) {
                    Text("Left-Right")
                }
                .buttonStyle(ToggleModeButtonStyle(isActive: appState.mode == .leftRight))
            }
            .padding(.horizontal)
            .disabled(disabled)
            .opacity(disabled ? 0.4 : 1.0)

            if appState.placementManager?.doesPlacedObjectHaveReferenceObject == true
            {
                // Snap Button (separate from mode buttons)
                
                Button(action: {
                    appState.placementManager?.snapButtonTapped()
                }) {
                    Text("Snap")
                }
                .buttonStyle(SnapButtonStyle(isDisabled: disabled))
                .padding(.top, 30)
                .padding(.horizontal)
                .disabled(disabled)
                
//                Button(action: {
//                    appState.placementManager?.snapButtonTapped()
//                }) {
//                    Text("Snap")
//                        .padding()
//                        .frame(maxWidth: .infinity)
//                        .background(Color.green)
//                        .cornerRadius(10)
//                        .foregroundColor(.white)
//                        .opacity(disabled ? 0.4 : 1.0)
//                }
//                .padding(.top, 30)
//                .padding(.horizontal)
//                .disabled(disabled)
                
                // Toggle switch for objectTracking mode
                Toggle(isOn: Binding<Bool>(
                    get: { appState.mode == .objectTracking },
                    set: { isOn in
                        appState.mode = isOn ? .objectTracking : nil
                    }
                )) {
                    Text("Object Tracking Mode")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .toggleStyle(.switch)
                .padding(.top, 20)
                .padding(.horizontal)
            }
            
            Spacer()

            Text("Tap a mode button to select or deselect a mode.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Position")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            appState.mode = nil
        }
    }

    // Toggle the mode: Select or deselect
    private func toggleMode(_ mode: AppState.InteractionMode) {
        if appState.mode == mode {
            appState.mode = nil // Deselect the mode if it's already selected
        } else {
            appState.mode = mode // Set the selected mode
        }
    }
}

struct ToggleModeButtonStyle: ButtonStyle {
    var isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive
                        ? (configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue)
                        : (configuration.isPressed ? Color.gray.opacity(0.25) : Color.gray.opacity(0.18))
                    )
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(color: isActive ? Color.blue.opacity(0.09) : Color.clear, radius: 4, y: 1)
            .animation(.easeInOut(duration: 0.13), value: configuration.isPressed)
            .hoverEffect(.highlight)
    }
}


struct SnapButtonStyle: ButtonStyle {
    var isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(isDisabled ? 0.5 : (configuration.isPressed ? 0.85 : 1)))
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(isDisabled ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.13), value: configuration.isPressed)
            .hoverEffect(.highlight)
    }
}


#Preview {
    PositionView(appState: AppState())
}
