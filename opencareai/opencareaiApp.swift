// opencareaiApp.swift
import SwiftUI
import Firebase

@main
struct opencareai: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.userSession == nil {
                    AuthenticationView()
                        .environmentObject(authViewModel)
                } else {
                    ContentView()
                        .environmentObject(authViewModel)
                        .environmentObject(appState)
                }
            }
            .preferredColorScheme(appState.colorScheme == .system ? nil : (appState.colorScheme == .dark ? .dark : .light))
        }
    }
}
