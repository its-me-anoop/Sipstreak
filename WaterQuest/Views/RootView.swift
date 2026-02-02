import SwiftUI

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    var body: some View {
        if hasOnboarded {
            MainTabView()
                
        } else {
            OnboardingView {
                hasOnboarded = true
            }
            
            
        }
    }
}
