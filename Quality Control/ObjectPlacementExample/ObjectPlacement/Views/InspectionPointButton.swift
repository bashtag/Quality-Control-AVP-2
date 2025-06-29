//
//  InspectionPointButton.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 12.01.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct InspectionPointButton: View {
    var pointName: String
    var isDisabled: Bool = false
    var tapHandler: (() -> Void)?

    var body: some View {
        Button(action: {
            tapHandler?()
        }) {
            Text(pointName)
                .font(.headline)
                .padding(10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .disabled(isDisabled)

    }
}
