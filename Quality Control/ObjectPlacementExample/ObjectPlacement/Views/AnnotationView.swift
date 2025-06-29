//
//  AnnotationView.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 17.03.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit
import ARKit
import UIKit

import SwiftUI
import _AppIntents_SwiftUI

struct AnnotationView: View {
    @Bindable var appState: AppState

    @State private var searchText: String = ""
    @State private var selectedTitle: String? = nil
    
    @State private var showEditSheet = false
    
    @StateObject var speechRecognizer = SpeechRecognizer()
     
        var filteredAnnotations: [PlacementManager.AnnotationModel] {
            if speechRecognizer.transcribedText.isEmpty {
                return appState.placementManager?.annotations ?? []
            }
            return (appState.placementManager?.annotations ?? []).filter {
                $0.title.localizedCaseInsensitiveContains(speechRecognizer.transcribedText) ||
                $0.description.localizedCaseInsensitiveContains(speechRecognizer.transcribedText)
            }
        }

    var annotationTitles: [String] {
        appState.placementManager?.annotationTitles ?? []
    }

    var filteredTitles: [String] {
        searchText.isEmpty ? annotationTitles :
        annotationTitles.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    // Get the focused annotation title
    var focusedAnnotationTitle: String? {
        guard let focusedId = appState.placementManager?.focusedAnnotationId else { return nil }
        return appState.placementManager?.getAnnotationTitleAndDescription(forAnnotationId: focusedId)?.title
    }
    
    var focusedAnnotation: (title: String, description: String, yesNo: Bool?)? {
        guard let info = appState.placementManager?.getFocusedAnnotationInfo() else { return nil }
        return (info.title, info.description, info.yesNoAnswer)
    }

    
    // remove popup
    @State private var pendingDeleteTitle: String? = nil
    @State private var showDeleteAlert = false
    @AppStorage("isVisible") private var isVisible: Bool = true
     
    var body: some View {
        VStack(spacing: 16) {
            SiriTipView(intent: SearchAnnotationsIntent(), isVisible: $isVisible)
            // Mode Toggle Button
            Button(action: {
                withAnimation {
                    appState.viewMode = (appState.viewMode == .addAnnotation) ? .viewAnnotations : .addAnnotation
                }
            }) {
                Text(appState.viewMode == .addAnnotation ? "Switch to View Mode" : "Switch to Add Mode")
                    .padding()
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            // Search Bar
            TextField("Search annotations by title", text: $searchText)
                .padding(8)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
                .foregroundColor(.white)
            
//            VStack
//                      {
//                          HStack
//                          {
//                              Button(action: {
//                                  speechRecognizer.startRecognition()
//                              }) {
//                                  Text("🎤 Start Voice Search")
//                              }
//                              .padding()
//                              Button("Stop") {
//                                  speechRecognizer.stopRecognition()
//                              }
//           
//                          }
//           
//                          Text("You said: \(speechRecognizer.transcribedText)")
//                              .padding()
//           
//                          List(filteredAnnotations) { annotation in
//                              VStack(alignment: .leading) {
//                                  Text(annotation.title)
//                                      .font(.headline)
//                                  Text(annotation.description)
//                                      .font(.subheadline)
//                              }
//                          }
//                      }

            // List of Filtered Annotations
            List(filteredTitles, id: \.self) { title in
                Button(action: {
                    selectedTitle = title
                    appState.placementManager?.focusAnnotation(withTitle: title)
                }) {
                    Text(title)
                        .foregroundColor(focusedAnnotationTitle == title ? .yellow : .white)
                        .frame(maxWidth: 400, alignment: .leading)
                        .lineLimit(1)
                }
                .listRowBackground(
                    focusedAnnotationTitle == title ?
                    Color.yellow.opacity(0.3) : Color.clear
                )
                .opacity(focusedAnnotationTitle == title ? 0.8 : 1.0)
            }
            .frame(maxHeight: 200)
            .scrollContentBackground(.hidden)
            
            if let title = selectedTitle {
                HStack(spacing: 12) {
                    Button("Change\n'\(title.truncated(to: 20))'") {
                        showEditSheet = true
                    }
                    .foregroundColor(.white)
                    .buttonStyle(PrimaryButtonStyle())
                    .multilineTextAlignment(.center)

                    Button("Remove\n'\(title.truncated(to: 20))'") {
                        pendingDeleteTitle = title
                        showDeleteAlert = true
                    }
                    .foregroundColor(.white)
                    .buttonStyle(DestructiveButtonStyle())
                    .multilineTextAlignment(.center)
                }
            }
            
            if let annotation = focusedAnnotation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(annotation.title)")
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(maxWidth: 400, alignment: .leading)
                            .lineLimit(2)
                        Text("\(annotation.description)")
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .frame(maxWidth: 400, alignment: .leading)
                            .lineLimit(3)
                        HStack {
                            Text("Yes/No Status:")
                                .foregroundColor(.white)
                                .font(.subheadline)
                            if let yesNo = annotation.yesNo {
                                Text(yesNo ? "Yes" : "No")
                                    .foregroundColor(yesNo ? .green : .red)
                                    .fontWeight(.bold)
                            } else {
                                Text("Unset")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.18))
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

        }
        .sheet(isPresented: Binding(
            get: { showEditSheet },
            set: { val in showEditSheet = val
            }
        )) {
            AddAnnotationView(appState: appState, uploadPreviouses: true, onFinish: {
                showEditSheet = false
            })
        }
        .sheet(isPresented: Binding(
                    get: { appState.isAnnotationAdded },
                    set: { val in appState.isAnnotationAdded = val
                    }
                )) {
                    AddAnnotationView(appState: appState)
                }
        .padding()
        .onAppear {
            appState.placementManager?.showAnnotations(animated: false)
            appState.viewMode = .viewAnnotations
            appState.isFocusedAnnotationChangable = true
            selectedTitle = focusedAnnotationTitle
            print("Showing annotation view")
            
            // debug
            if let siriQuery = UserDefaults.standard.string(forKey: "siriAnnotationQuery") {
                               speechRecognizer.transcribedText = siriQuery
                               UserDefaults.standard.removeObject(forKey: "siriAnnotationQuery")
                               print("Siri search query received: \(siriQuery)")
                           }
        }
        .onChange(of: focusedAnnotationTitle) { oldValue, newValue in
                    // Update selectedTitle when focus changes
                    selectedTitle = newValue
                }
        .onChange(of: AppIntentsController.shared.searchText) { _, newValue in
                print("SEARCH TEXT :", newValue)
                    searchText = newValue
                }
        .onDisappear {
            appState.placementManager?.hideAnnotations(animated: false)
            appState.viewMode = .other
            print("Hiding annotation view")
        }
        .cornerRadius(20)
        .padding()
        .alert("Are you sure you want to remove '\(pendingDeleteTitle ?? "")'?", isPresented: $showDeleteAlert, actions: {
            Button("Delete", role: .destructive) {
                if let titleToDelete = pendingDeleteTitle {
                    appState.placementManager?.removeFocusedAnnotation()
                    selectedTitle = nil
                    pendingDeleteTitle = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteTitle = nil
            }
        })
        .onChange(of: showDeleteAlert) { _, isPresented in
            appState.isFocusedAnnotationChangable = !isPresented
        }
        .navigationTitle("Annotation")
        .navigationBarTitleDisplayMode(.inline)

    }
}

extension String {
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count <= length {
            return self
        } else {
            return String(self.prefix(length - trailing.count)) + trailing
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(configuration.isPressed ? 0.7 : 0.85))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(color: .blue.opacity(0.13), radius: 3, y: 2)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            .hoverEffect(.highlight)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.7 : 0.85))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(color: .red.opacity(0.12), radius: 3, y: 2)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            .hoverEffect(.highlight)
    }
}


#Preview {
    let previewAppState = AppState.previewAppState(immersiveSpaceOpened: true)
    
    // Simulated AnnotationModel instances
    previewAppState.placementManager?.annotations = [
        PlacementManager.AnnotationModel(
            id: UUID().uuidString,
            title: "Engine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine PortEngine Port",
            description: "Check the bolts for tightness.",
            worldPosition: SIMD3<Float>(0, 0, 0),
            localPosition: SIMD3<Float>(0, 0, -0.5)
        ),
        PlacementManager.AnnotationModel(
            id: UUID().uuidString,
            title: "Panel B",
            description: "Minor misalignment detected.",
            worldPosition: SIMD3<Float>(1, 0, 0),
            localPosition: SIMD3<Float>(0, 0, 0.5)
        ),
        PlacementManager.AnnotationModel(
            id: UUID().uuidString,
            title: "Main Shaft",
            description: "Crack detected near base.",
            worldPosition: SIMD3<Float>(0, 1, 0),
            localPosition: SIMD3<Float>(0, 0, 0)
        )
    ]

    return AnnotationView(appState: previewAppState)
        .preferredColorScheme(.dark)
}
