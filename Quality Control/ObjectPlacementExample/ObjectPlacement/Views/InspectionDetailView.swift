//
//  InspectionDetailView.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 12.01.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct InspectionDetailView: View {
    var appState: AppState

    @State private var countAnswer: Int? = nil
    @State private var descriptionAnswer: String = ""
    @State private var yesNoAnswer: Bool? = nil
    @State private var question: String = "" // For inspectionName (stored in .name)
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack {
            Text("Inspection Point Details")
                .font(.title)
                .padding()

            if let highlightedPoint = appState.highlightedPoint {
                Text("You are inspecting: \(highlightedPoint.rawValue)")
                    .padding()

                switch highlightedPoint {
                case .forCount:
                    CountInspectionView(answer: $countAnswer, question: $question)
                case .forDescription:
                    DescriptionInspectionView(answer: $descriptionAnswer, question: $question)
                case .forYesNoQuestion:
                    YesNoInspectionView(selection: $yesNoAnswer, question: $question)
                }
            } else {
                Text("No point selected.")
                    .foregroundColor(.gray)
                    .padding()
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered)
                .padding()

                Button("Save") {
                    saveInspection()
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .onAppear {
            loadInspectionState()
        }
        .onDisappear {
            appState.isInspectionDetailsOpen = false
        }
        .navigationTitle("Inspection Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadInspectionState() {
        guard let highlightedPoint = appState.highlightedPoint,
              let objectName = appState.placementManager?.placementState.placedObject?.fileName,
              let inspectionPoint = appState.getInspectionPoint(for: objectName, type: highlightedPoint) else {
            return
        }

        question = inspectionPoint.name // Load inspectionName
        countAnswer = inspectionPoint.count
        descriptionAnswer = inspectionPoint.description ?? ""
        yesNoAnswer = inspectionPoint.isCorrect
    }

    private func saveInspection() {
        guard let highlightedPoint = appState.highlightedPoint,
              let objectName = appState.placementManager?.placementState.placedObject?.fileName else {
            return
        }

        // Save the inspection point to AppState
        appState.updateInspectionPoint(
            for: objectName,
            type: highlightedPoint,
            count: countAnswer,
            description: descriptionAnswer,
            isCorrect: yesNoAnswer
        )
    }
}

struct DescriptionInspectionView: View {
    @Binding var answer: String
    @Binding var question: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(question) // Display the question
                .font(.headline)
                .padding(.bottom, 4)

            Text("Provide a description:")
                .font(.subheadline)
                .padding(.bottom, 4)

            TextEditor(text: $answer)
                .frame(height: 100)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                .padding(.bottom, 8)
        }
        .padding()
    }
}


struct YesNoInspectionView: View {
    @Binding var selection: Bool?
    @Binding var question: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(question) // Display the question
                .font(.headline)
                .padding(.bottom, 4)


            HStack {
                Button(action: {
                    selection = true
                }) {
                    HStack {
                        Image(systemName: selection == true ? "checkmark.circle.fill" : "circle")
                        Text("Yes")
                    }
                }
                .buttonStyle(.bordered)

                Button(action: {
                    selection = false
                }) {
                    HStack {
                        Image(systemName: selection == false ? "checkmark.circle.fill" : "circle")
                        Text("No")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 8)
        }
        .padding()
    }
}

struct CountInspectionView: View {
    @Binding var answer: Int?
    @Binding var question: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(question) // Display the question
                .font(.headline)
                .padding(.bottom, 4)


            TextField("Enter count", value: $answer, format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .padding(.bottom, 8)
        }
        .padding()
    }
}




//struct InspectionDetailView: View {
//    var appState: AppState
//
//    @State private var countAnswer: Int? = nil
//    @State private var descriptionAnswer: String = ""
//    @State private var yesNoAnswer: Bool? = nil
//    @Environment(\.presentationMode) private var presentationMode
//
//    var body: some View {
//        VStack {
//            Text("Inspection Point Details")
//                .font(.title)
//                .padding()
//
//            if let highlightedPoint = appState.highlightedPoint {
//                Text("You are inspecting: \(highlightedPoint.rawValue)")
//                    .padding()
//
//                switch highlightedPoint {
//                case .forCount:
//                    CountInspectionView(answer: $countAnswer)
//                case .forDescription:
//                    DescriptionInspectionView(answer: $descriptionAnswer)
//                case .forYesNoQuestion:
//                    YesNoInspectionView(selection: $yesNoAnswer)
//                }
//            } else {
//                Text("No point selected.")
//                    .foregroundColor(.gray)
//                    .padding()
//            }
//
//            Spacer()
//
//            HStack {
//                Button("Cancel") {
//                    presentationMode.wrappedValue.dismiss()
//                }
//                .buttonStyle(.bordered)
//                .padding()
//
//                Button("Save") {
//                    saveInspection()
//                    presentationMode.wrappedValue.dismiss()
//                }
//                .buttonStyle(.borderedProminent)
//                .padding()
//            }
//        }
//        .onAppear {
//            loadInspectionState()
//        }
//        .onDisappear {
//            appState.isInspectionDetailsOpen = false
//        }
//        .onChange(of: yesNoAnswer) { newValue in
//            print("ÇALIŞIYOR HAA :\(newValue)")
//            yesNoAnswer = newValue
//            
//        }
//        .navigationTitle("Inspection Details")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//    
//    private func loadInspectionState() {
//        guard let highlightedPoint = appState.highlightedPoint,
//              let objectName = appState.placementManager?.placementState.placedObject?.fileName,
//              let inspectionPoint = appState.getInspectionPoint(for: objectName, type: highlightedPoint) else {
//            return
//        }
//
//        countAnswer = inspectionPoint.count
//        descriptionAnswer = inspectionPoint.description ?? ""
//        yesNoAnswer = inspectionPoint.isCorrect
//    }
//
//    private func saveInspection() {
//        guard let highlightedPoint = appState.highlightedPoint,
//              let objectName = appState.placementManager?.placementState.placedObject?.fileName else {
//            return
//        }
//
//        // Save the inspection point to AppState
//        appState.updateInspectionPoint(
//            for: objectName,
//            type: highlightedPoint,
//            count: countAnswer,
//            description: descriptionAnswer,
//            isCorrect: yesNoAnswer
//        )
//    }


//    private func loadInspectionState() {
//            if let highlightedPoint = appState.highlightedPoint,
//               let inspectionPoint = appState.getInspectionPoint(for: highlightedPoint) {
//                countAnswer = inspectionPoint.count
//                descriptionAnswer = inspectionPoint.description ?? ""
//                yesNoAnswer = inspectionPoint.isCorrect
//            }
//        }
//
//        private func saveInspection() {
//            guard let highlightedPoint = appState.highlightedPoint else { return }
//
//            // Save the inspection point to AppState
//            appState.updateInspectionPoint(
//                for: highlightedPoint,
//                count: countAnswer,
//                description: descriptionAnswer,
//                isCorrect: yesNoAnswer
//            )
//            
//            
//        }
//}

//// MARK: - Count Inspection View
//struct CountInspectionView: View {
//    @Binding var answer: Int?
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            Text("How many objects are there?")
//                .font(.headline)
//                .padding(.bottom, 4)
//
//            TextField("Enter count", value: $answer, format: .number)
//                .textFieldStyle(.roundedBorder)
//                .keyboardType(.numberPad)
//                .padding(.bottom, 8)
//        }
//        .padding()
//    }
//}
//
//
//// MARK: - Description Inspection View
//struct DescriptionInspectionView: View {
//    @Binding var answer: String
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            Text("Provide a description:")
//                .font(.headline)
//                .padding(.bottom, 4)
//
//            TextEditor(text: $answer)
//                .frame(height: 100)
//                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
//                .padding(.bottom, 8)
//        }
//        .padding()
//    }
//}
//
//// MARK: - Yes/No Inspection View
//struct YesNoInspectionView: View {
//    @Binding var selection: Bool?
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            Text("Is the object in good condition?")
//                .font(.headline)
//                .padding(.bottom, 4)
//
//            HStack {
//                Button(action: {
//                    selection = true
//                    print("why is it not working in button")
//                }) {
//                    HStack {
//                        Image(systemName: selection == true ? "checkmark.circle.fill" : "circle")
//                        Text("Yes")
//                    }
//                }
//                .buttonStyle(.bordered)
//
//                Button(action: {
//                    selection = false
//                }) {
//                    HStack {
//                        Image(systemName: selection == false ? "checkmark.circle.fill" : "circle")
//                        Text("No")
//                    }
//                }
//                .buttonStyle(.bordered)
//            }
//            .padding(.bottom, 8)
//        }
//        .padding()
//    }
//}


//
//import SwiftUI
//
//struct InspectionDetailView: View {
//    var appState: AppState
//
//    var body: some View {
//        VStack {
//            Text("Inspection Point Details")
//                .font(.title)
//                .padding()
//
//            if let highlightedPoint = appState.highlightedPoint {
//                Text("You are inspecting: \(highlightedPoint.rawValue ?? "Unnamed Point")")
//                    .padding()
//            } else {
//                Text("No point selected.")
//                    .foregroundColor(.gray)
//                    .padding()
//            }
//
//            Button("Perform Action with Highlighted Point") {
//                if let highlightedPoint = appState.highlightedPoint {
//                    print("Performing action for \(highlightedPoint.rawValue ?? "Unnamed Point")")
//                }
//            }
//
//            Button("Back") {
//                // NavigationStack handles back navigation automatically
//            }
//            .buttonStyle(.bordered)
//        }
//        .onDisappear() {
//            appState.isInspectionDetailsOpen = false
//        }
//        .navigationTitle("Inspection Details")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}
