//
//  ObjectDetailView.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 11.01.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct ObjectDetailView: View {
    var appState: AppState
    let onDelete: () -> Void
    
    @State private var presentConfirmationDialog = false
    @State var navigationPath: [String] = [] // Path to manage navigation
    
    // Report generation states
    @State private var isGeneratingReport: Bool = false
    @State private var reportGenerationSuccess: Bool = false
    @State private var reportError: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 20) {
                Button("Position") {
                    navigationPath.append("Position")
                }
                .buttonStyle(.bordered)

                Button("Inspection") {
                    navigationPath.append("Inspection")
                }
                .buttonStyle(.bordered)
                
                // DEBUG
                Button("Annotation") {
                    navigationPath.append("Annotation")
//                    appState.viewMode = .annotation
                }
                .buttonStyle(.bordered)
                // END DEBUG
                
                // Generate Report Button
                Button(action: generateReport) {
                    Text("Generate Report")
                        .font(.headline)
//                        .padding()
//                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
                .disabled(isGeneratingReport)
                
                // Report generation feedback
                if isGeneratingReport {
                    ProgressView("Generating Report...")
                        .padding()
                }
                if let reportError = reportError {
                    Text("Error: \(reportError)")
                        .foregroundColor(.red)
                        .padding()
                }
                if reportGenerationSuccess {
                    Text("Report generated successfully!")
                        .foregroundColor(.green)
                        .padding()
                }
                
                Button("Remove", systemImage: "trash") {
                    presentConfirmationDialog = true
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .buttonStyle(.borderless)
                .confirmationDialog("Remove the object?", isPresented: $presentConfirmationDialog, titleVisibility: .visible) {
                    Button("Remove", role: .destructive) {
                        onDelete()
                    }
                }
            }
            .navigationTitle("Object Details")
            .navigationDestination(for: String.self) { destination in
                if destination == "Position" {
                    PositionView(appState: appState)
                } else if destination == "Inspection" {
                    InspectionView(appState: appState)
                }
                else if destination == "InspectionDetail"
                {
                    InspectionDetailView(appState: appState)
                }
                else if destination == "Annotation"
                {
                    AnnotationView(appState: appState)
                }
            }
            .padding()
            .onChange(of: appState.isInspectionDetailsOpen) { newVal in
                if newVal == false
                {
                    return
                }
                        navigationPath.append("InspectionDetail")
                        print("Navigation path changed in ODV: \(newVal)")
                    }
        }
        
    }
    
    private func generateReport() {
            isGeneratingReport = true
            reportGenerationSuccess = false
            reportError = nil

            Task {
                do {
                    // Ensure the placement manager and placed object are available
                    guard let placementManager = appState.placementManager,
                          let placedObject = placementManager.placementState.placedObject else {
                        throw NSError(domain: "ReportGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "No object available for report generation"])
                    }

                    // Calculate object dimensions
                    let dimensions = placedObject.extents
                    let width = Double(dimensions.x)
                    let height = Double(dimensions.y)
                    let depth = Double(dimensions.z)

                    // Use the object's name
                    let objectName = placedObject.fileName
                    
                    // Get inspection points for this object
                    let inspectionPoints = appState.inspectionPoints[objectName]?.values.map { $0 } ?? []
                    
                    // Convert AppState annotations to ReportAnnotation format
                    let reportAnnotations = (appState.placementManager?.annotations ?? []).map { annotation in
                                        ReportAnnotation(
                                            id: annotation.id,
                                            title: annotation.title,
                                            description: annotation.description,
                                            yesNoAnswer: annotation.yesNoAnswer
                                        )
                                    }

                    // Create a VirtualObject using the dynamic data
                    let virtualObject = VirtualObject(
                        name: objectName,
                        width: width,
                        height: height,
                        depth: depth,
                        inspectionPoints: inspectionPoints,
                        annotations: reportAnnotations
                    )

                    // Define the reports directory
                    let reportsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path

                    // Create a ReportGenerator instance
                    let reportGenerator = ReportGenerator(for: virtualObject, reportsDirectory: reportsDirectory)

                    // Generate the report
                    try reportGenerator.createReport()
                    reportGenerationSuccess = true
                    print("Report generated at: \(reportGenerator.filePath)")
                } catch {
                    reportError = error.localizedDescription
                }
                isGeneratingReport = false
            }
        }
}

#Preview {
    ObjectDetailView(appState: AppState(), onDelete: {})
}
