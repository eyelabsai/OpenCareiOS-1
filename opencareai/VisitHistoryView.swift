//
//  VisitHistoryView.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/3/25.
//  Revised 7/12/25 – transcript extraction made safe.
//

import SwiftUI

// MARK: - Visit History List
struct VisitHistoryView: View {
    @StateObject private var viewModel = VisitHistoryViewModel()
    
    @State private var selectedFilter = "All"
    @State private var searchText     = ""
    
    private let filters = [
        "All", "Pain Management", "Internal Medicine"
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Filter bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filters, id: \.self) { filt in
                            Button {
                                selectedFilter = filt
                                viewModel.filterVisits(by: filt)
                            } label: {
                                Text(filt)
                                    .font(.caption)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(selectedFilter == filt ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedFilter == filt ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Search visits…", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: searchText) { _ in
                            viewModel.searchVisits(query: searchText)
                        }
                }
                .padding(.horizontal)
                
                // Visits list
                if viewModel.isLoading {
                    Spacer(); ProgressView("Loading visits…"); Spacer()
                } else if viewModel.filteredVisits.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 60)).foregroundColor(.gray)
                        Text("No visits found").font(.title2).fontWeight(.semibold)
                        Text("Start recording your first medical visit to see it here")
                            .font(.body).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    List(viewModel.filteredVisits) { visit in
                        NavigationLink(destination: VisitHistoryDetailView(visit: visit)) {
                            VisitRowView(visit: visit)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                Task {
                                    await viewModel.deleteVisit(visit)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Visit History")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { 
                Task {
                    await viewModel.fetchVisits()
                }
            }
            .refreshable { 
                await viewModel.fetchVisits()
            }
        }
    }
}

// MARK: - Visit Detail
struct VisitHistoryDetailView: View {
    let visit: Visit
    @State private var showingTranscript  = false
    @State private var showingMedications = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(visit.specialty ?? "")
                        .font(.largeTitle).fontWeight(.bold)
                    Text(formatDate(visit.date ?? Date()))
                        .font(.subheadline).foregroundColor(.secondary)
                    Text(visit.tldr ?? "")
                        .font(.body).foregroundColor(.secondary)
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1)).cornerRadius(8)
                }
                // Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Summary").font(.headline).fontWeight(.semibold)
                    Text(visit.summary ?? "")
                        .font(.body).lineSpacing(4)
                }
                // Medications
                if !(visit.medications ?? []).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Medications Prescribed")
                                .font(.headline).fontWeight(.semibold)
                            Spacer()
                            Button("View All") { showingMedications = true }
                                .font(.caption)
                        }
                        ForEach((visit.medications ?? []).prefix(3)) { med in
                            MedicationDetailRow(medication: med)
                        }
                        if (visit.medications ?? []).count > 3 {
                            Text("+ \((visit.medications ?? []).count - 3) more medications")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                // Transcript
                let transcript = extractTranscript(from: visit)
                if !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Full Transcript")
                                .font(.headline).fontWeight(.semibold)
                            Spacer()
                            Button(showingTranscript ? "Hide" : "Show") {
                                withAnimation { showingTranscript.toggle() }
                            }
                            .font(.caption)
                        }
                        if showingTranscript {
                            Text(transcript)
                                .font(.body).lineSpacing(4)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Visit Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMedications) {
            MedicationsListView(medications: visit.medications ?? [],
                                title: "Medications from \(visit.specialty ?? "") Visit")
        }
    }
    
    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }
    
    /// Gracefully extracts a transcript string if any known key exists.
    private func extractTranscript(from visit: Visit) -> String {
        let keys = ["transcript", "fullTranscript", "rawTranscript"]
        let mirror = Mirror(reflecting: visit)
        for child in mirror.children {
            if let label = child.label, keys.contains(label),
               let str = child.value as? String { return str }
        }
        return ""
    }
}

// MARK: - Reusable Sub-Views
struct MedicationDetailRow: View {
    let medication: Medication
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(medication.name)
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text(medication.dosage)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
            }
            Text(medication.fullInstructions ?? "")
                .font(.caption).foregroundColor(.secondary).lineLimit(2)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MedicationsListView: View {
    let medications: [Medication]
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            List(medications) { med in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(med.name)
                            .font(.headline).fontWeight(.semibold)
                        Spacer()
                        Text(med.dosage)
                            .font(.subheadline)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    Text("Frequency: \(med.frequency)")
                        .font(.subheadline).foregroundColor(.secondary)
                    if let timing = med.timing {
                        Text("Timing: \(timing)")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    Text(med.fullInstructions ?? "")
                        .font(.body).padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
