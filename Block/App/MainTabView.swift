import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house"){
                HomeView()
            }
            Tab("App Select", systemImage: "app.shadow"){
                AppSelectView()
            }
        }
        
    }
}

#Preview {
    MainTabView()
}
