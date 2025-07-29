//
//  HomeView.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/3/25.
//  Revised 7/21/25 – Rebuilt to match modern web app dashboard layout.
//

import SwiftUI
import AVFoundation

// MARK: - Main Home View (Dashboard)
struct HomeView: View {
    @EnvironmentObject var visitViewModel: VisitViewModel
    @EnvironmentObject var statsViewModel: StatsViewModel
    @EnvironmentObject var audioRecorder: AudioRecorder
    @EnvironmentObject var medicationViewModel: MedicationViewModel
    @Binding var selectedTab: Int
    
    @State private var showingVisitPrep = false
    @State private var showingNewVisit = false
    @State private var showingVisitDetail = false
    @State private var showingHealthAssistant = false
    @State private var showingMedicationDetail = false
    @State private var selectedVisit: Visit?
    @State private var selectedMedication: Medication?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header with welcome message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome back!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Here is your health summary.")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    // Stats Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 2), spacing: 20) {
                        DashboardStatCard(
                            title: "Total Visits",
                            value: "\(visitViewModel.totalVisits)",
                            icon: "calendar",
                            color: .blue,
                            gradient: LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        DashboardStatCard(
                            title: "Visits This Month",
                            value: "\(visitViewModel.visitsThisMonth)",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .green,
                            gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        DashboardStatCard(
                            title: "Active Meds",
                            value: "\(statsViewModel.currentMedications.count)",
                            icon: "pills",
                            color: .orange,
                            gradient: LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        DashboardStatCard(
                            title: "Specialties",
                            value: "\(visitViewModel.specialties.count)",
                            icon: "stethoscope",
                            color: .purple,
                            gradient: LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    }
                    .padding(.horizontal, 24)

                    // Quick Actions Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Quick Actions")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.leading, 4)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            QuickActionCard(title: "Record Visit", icon: "mic.fill", color: .blue) { showingNewVisit = true }
                            QuickActionCard(title: "View History", icon: "clock.fill", color: .green) { selectedTab = 1 }
                            QuickActionCard(title: "Prepare for Visit", icon: "list.clipboard.fill", color: .purple) { showingVisitPrep = true }
                            QuickActionCard(title: "Medications", icon: "pills.fill", color: .orange) { selectedTab = 2 }
                            QuickActionCard(title: "Health Assistant", icon: "message.fill", color: .purple) { showingHealthAssistant = true }
                        }
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 8)

                    // Recent Visits Section
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Recent Visits")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                            Button("View All") { selectedTab = 1 }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        if visitViewModel.isLoading {
                            ProgressView()
                                .frame(height: 200)
                        } else if visitViewModel.recentVisits.isEmpty {
                            Text("No recent visits found.")
                                .foregroundColor(.secondary)
                                .frame(height: 100)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(visitViewModel.recentVisits) { visit in
                                    VisitItem(
                                        visit: visit,
                                        onTap: {
                                            selectedVisit = visit
                                            showingVisitDetail = true
                                        },
                                        onDelete: {
                                            Task { await visitViewModel.deleteVisit(visit) }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 8)
                }
                .padding(.vertical, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewVisit = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingNewVisit) {
                // You will need to create this view next
                // NewVisitView()
                //     .environmentObject(visitViewModel)
                //     .environmentObject(audioRecorder)
            }
            .sheet(isPresented: $showingVisitPrep) {
                VisitPrepView(
                    visits: visitViewModel.visits,
                    medications: medicationViewModel.medications
                )
            }
            .sheet(isPresented: $showingVisitDetail) {
                if let visit = selectedVisit {
                    VisitDetailView(visit: visit)
                        .environmentObject(visitViewModel)
                }
            }
            .sheet(isPresented: $showingHealthAssistant) {
                HealthAssistantView()
            }
            .onAppear {
                Task {
                    await visitViewModel.loadVisitsAsync()
                    await statsViewModel.fetchStats()
                }
            }
        }
    }
}

// MARK: - Dashboard Stat Card
struct DashboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let gradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Spacer()

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
