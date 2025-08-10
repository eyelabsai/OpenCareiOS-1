//
//  OnboardingView.swift
//  opencareai
//
//  Created by Claude on 8/10/25.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @Binding var showOnboarding: Bool
    
    private let totalPages = 6
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemGroupedBackground), Color.blue.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    WelcomeOnboardingScreen()
                        .tag(0)
                    
                    HealthSyncOnboardingScreen()
                        .tag(1)
                    
                    VisitRecordingOnboardingScreen()
                        .tag(2)
                    
                    MedicationTrackingOnboardingScreen()
                        .tag(3)
                    
                    AnalyticsOnboardingScreen()
                        .tag(4)
                    
                    GetStartedOnboardingScreen(showOnboarding: $showOnboarding)
                        .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Custom page indicators and navigation
                VStack(spacing: 24) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }
                    
                    // Navigation buttons
                    HStack {
                        if currentPage > 0 {
                            Button("Previous") {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if currentPage < totalPages - 1 {
                            Button("Next") {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(25)
                        }
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .dynamicTypeSize(.large...(.accessibility5))
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        showOnboarding = false
    }
}

// MARK: - Welcome Screen
struct WelcomeOnboardingScreen: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 16) {
                    Text("Welcome to OpenCare")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                    
                    Text("Your AI-powered health assistant that helps you manage your medical visits, medications, and health data all in one place.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Health Sync Screen
struct HealthSyncOnboardingScreen: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                VStack(spacing: 16) {
                    Text("Apple Health Integration")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Automatically sync your health data including height, weight, medications, and vital signs from Apple Health for a complete picture of your wellness.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            VStack(spacing: 16) {
                FeatureRow(icon: "figure", title: "Physical Measurements", description: "Height, weight, and body metrics")
                FeatureRow(icon: "pills", title: "Medications", description: "Track prescriptions and supplements")
                FeatureRow(icon: "waveform.path.ecg", title: "Vital Signs", description: "Heart rate, blood pressure, and more")
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Visit Recording Screen
struct VisitRecordingOnboardingScreen: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                VStack(spacing: 16) {
                    Text("Record Medical Visits")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Easily document your doctor visits with AI-powered voice recording and automatic transcription. Never forget important medical advice again.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            VStack(spacing: 16) {
                FeatureRow(icon: "mic.fill", title: "Voice Recording", description: "Record conversations with your doctor")
                FeatureRow(icon: "doc.text", title: "AI Transcription", description: "Automatic conversion to text summaries")
                FeatureRow(icon: "folder", title: "Visit History", description: "Access all your medical records anytime")
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Medication Tracking Screen
struct MedicationTrackingOnboardingScreen: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                VStack(spacing: 16) {
                    Text("Smart Medication Management")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Keep track of all your medications with intelligent scheduling, dosage reminders, and automatic health data synchronization.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            VStack(spacing: 16) {
                FeatureRow(icon: "clock.fill", title: "Smart Scheduling", description: "AI-powered medication timing")
                FeatureRow(icon: "bell.fill", title: "Reminders", description: "Never miss a dose with notifications")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking", description: "Monitor treatment effectiveness")
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Analytics Screen
struct AnalyticsOnboardingScreen: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.purple)
                
                VStack(spacing: 16) {
                    Text("Health Analytics & Insights")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Get personalized insights about your health trends, visit patterns, and medication effectiveness with beautiful charts and analytics.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            VStack(spacing: 16) {
                FeatureRow(icon: "chart.pie.fill", title: "Visit Analytics", description: "Track patterns across specialties")
                FeatureRow(icon: "waveform.path.ecg", title: "Health Trends", description: "Monitor your progress over time")
                FeatureRow(icon: "brain.head.profile", title: "AI Insights", description: "Personalized health recommendations")
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Get Started Screen
struct GetStartedOnboardingScreen: View {
    @Binding var showOnboarding: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.green)
                
                VStack(spacing: 16) {
                    Text("You're All Set!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Start your health journey with OpenCare. Record your first visit, sync your health data, or explore your personalized dashboard.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Button(action: {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                showOnboarding = false
            }) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Get Started")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(25)
                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Feature Row Component
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}