//
//  AddAnnotationView.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 19.06.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct AddAnnotationView: View {
    @Bindable var appState: AppState
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var yesNoAnswer: Bool? = nil
    var uploadPreviouses: Bool = false
    var onFinish: () -> Void = {}

    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set Annotation Details")
                .font(.title2)
            TextField("Title", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            TextField("Description", text: $description)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // Optional Yes/No input
            HStack {
                Text("Yes/No Answer:")
                Spacer()
                Picker("", selection: Binding(
                    get: { yesNoAnswer ?? false ? 1 : (yesNoAnswer == nil ? 2 : 0) },
                    set: { val in
                        if val == 2 {
                            yesNoAnswer = nil
                        } else {
                            yesNoAnswer = (val == 1)
                        }
                    }
                )) {
                    Text("No").tag(0)
                    Text("Yes").tag(1)
                    Text("Not set").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            HStack {
                Button("Cancel") {
                    // Clear focus and preview annotation (or whatever your cancel logic is)
                    if !uploadPreviouses {
                        appState.placementManager?.removeFocusedAnnotation()
                    }
                    
                    appState.placementManager?.focusedAnnotationId = nil
                    appState.isAnnotationAdded = false
                    onFinish()
                }
                Spacer()
                Button("Save") {
                    appState.placementManager?.updateFocusedAnnotation(title: title, description: description, yesNoAnswer: yesNoAnswer)
                    appState.isAnnotationAdded = false
                    onFinish()
                }
                .disabled(title.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding()
        .onAppear {
            appState.viewMode = .viewAnnotations
            appState.isFocusedAnnotationChangable = false
            // Prefill if editing existing
            if uploadPreviouses, let id = appState.placementManager?.focusedAnnotationId,
               let anno = appState.placementManager?.annotations.first(where: { $0.id == id }) {
                title = anno.title
                description = anno.description
                yesNoAnswer = anno.yesNoAnswer
            }
        }
        .onDisappear {
            appState.isFocusedAnnotationChangable = true
        }
    }
}

#Preview {
    AddAnnotationView(appState: AppState())
}
