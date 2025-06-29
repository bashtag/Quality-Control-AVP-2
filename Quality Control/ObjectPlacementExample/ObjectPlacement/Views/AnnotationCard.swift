import SwiftUI

struct AnnotationCard: View {
    var appState: AppState
    var id: String
    var title: String
    var description: String
    var yesNoAnswer: Bool?
    
//    var isFocused: Bool = true
    // Computed property for expansion
    private var isFocused: Bool {
        appState.placementManager?.focusedAnnotationId == id
    }
    
    // Computed background color
    private var cardBackground: Color {
        switch yesNoAnswer {
        case .some(true):
            return Color(.sRGB, red: 0.75, green: 1.0, blue: 0.75, opacity: 0.45) // Soft green
        case .some(false):
            return Color(.sRGB, red: 1.0, green: 0.8, blue: 0.8, opacity: 0.45)   // Soft red
        case .none:
            return Color.black.opacity(0.7)
        }
    }

    var body: some View {
        Button(action: {
            if appState.isFocusedAnnotationChangable {
                appState.placementManager?.focusedAnnotationId = id
            }
        }) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 48))
                    .frame(width: 48, height: 48)
                    .foregroundColor(isFocused ? .blue : .white)
                    
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .hoverEffect(FadeEffect())
                        .lineLimit(1)
                        .frame(maxWidth: 150, alignment: .leading)
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .hoverEffect(FadeEffect())
                        .lineLimit(2)
                        .frame(maxWidth: 150, alignment: .leading)
                }
            }
            .padding()
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 64)
                    .stroke(isFocused ? Color.blue : Color.clear, lineWidth: isFocused ? 8 : 0)
                    .frame(height: 80)
                    .hoverEffect(BorderEffect())
            }
        }
        .buttonStyle(AnnotationCardStyle(cardBackground: cardBackground))
        .hoverEffectGroup()
        .disabled(appState.viewMode == .addAnnotation)
        .allowsHitTesting(appState.viewMode != .addAnnotation)
        .onChange(of: appState.placementManager?.focusedAnnotationId) { oldValue, newValue in
            print("🔍 DEBUG: focusedAnnotationId changed from '\(oldValue ?? "nil")' to '\(newValue ?? "nil")'")
            print("📍 DEBUG: Card '\(id)' - isFocused: \(isFocused)")
            print("---")
        }
        .onChange(of: isFocused) { oldValue, newValue in
            print("🎯 DEBUG: Card '\(id)' - isFocused changed from \(oldValue) to \(newValue)")
        }
    }

    struct AnnotationCardStyle: ButtonStyle {
        var cardBackground: Color

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(cardBackground)
                .cornerRadius(12)
                .hoverEffect(.highlight)
                .hoverEffect(ExpandEffect())
        }
    }

    struct ExpandEffect: CustomHoverEffect {
        func body(content: Content) -> some CustomHoverEffect {
            content.hoverEffect { effect, isActive, proxy in
                return effect.animation(.easeInOut(duration: 0.3).delay(isActive ? 0.6 : 0.1)) {
                    $0.clipShape(.capsule.size(
                        width: isActive ? proxy.size.width : proxy.size.height,
                        height: proxy.size.height,
                        anchor: .leading
                    ))
                }
                .scaleEffect(isActive ? 1.1 : 1.0)
            }
        }
    }
    
    struct BorderEffect: CustomHoverEffect {
        func body(content: Content) -> some CustomHoverEffect {
            content.hoverEffect { effect, isActive, proxy in
                return effect.animation(.easeInOut(duration: 0.3).delay(isActive ? 0.6 : 0.1)) {
                    $0.clipShape(.capsule.size(
                        width: isActive ? proxy.size.width : proxy.size.height*0.5, // Use relative sizing
                        height: proxy.size.height,
                        anchor: .leading
                    ))
                }
            }
        }
    }

    struct FadeEffect: CustomHoverEffect {
        var from: Double = 0
        var to: Double = 1

        func body(content: Content) -> some CustomHoverEffect {
            content.hoverEffect { effect, isActive, _ in
                effect.animation(.easeInOut(duration: 0.3).delay(isActive ? 0.3 : 0.1)) {
                    $0.opacity(isActive ? to : from)
                }
            }
        }
    }
}

#Preview(windowStyle: .plain) {
    let appState = AppState()
    appState.placementManager?.focusedAnnotationId = "demoID"
    return AnnotationCard(appState: appState, id: "demoID", title: "Test Point Title If You Liked", description: "Long test description and it is a very long text. You can read it til you die.", yesNoAnswer: nil)
}
