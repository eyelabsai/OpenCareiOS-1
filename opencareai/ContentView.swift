// Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject var medicationViewModel = MedicationViewModel() // Shared instance
    @StateObject var visitViewModel = VisitViewModel() // Shared instance
    @StateObject var statsViewModel = StatsViewModel() // Shared instance
    @StateObject var audioRecorder = AudioRecorder() // Shared instance
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill") // Changed label
                }
                .tag(0)
                .environmentObject(medicationViewModel)
                .environmentObject(visitViewModel)
                .environmentObject(statsViewModel)
                .environmentObject(audioRecorder)
            
            VisitHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)
                .environmentObject(visitViewModel) // Pass VisitViewModel here

            MedicationView()
                .tabItem {
                    Label("Meds", systemImage: "pills.fill")
                }
                .tag(2)
                .environmentObject(medicationViewModel)
            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.xaxis")
                }
                .tag(3) // Make sure the tag is unique
                .environmentObject(visitViewModel) // Pass the view models
                .environmentObject(statsViewModel)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
                .environmentObject(visitViewModel)
                .environmentObject(medicationViewModel)
            
        }
        .accentColor(.blue)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
