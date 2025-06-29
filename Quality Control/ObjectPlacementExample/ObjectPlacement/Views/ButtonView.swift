//
//  ButtonView.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 12.01.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct ButtonView: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            Text(title)
                .font(.system(size: 10))
                .padding(5)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(5)
        }
        .frame(width: 50, height: 20)
    }
}
