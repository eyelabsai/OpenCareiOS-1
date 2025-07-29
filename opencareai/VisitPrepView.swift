//
//  VisitPrepView.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/21/25.
//


import SwiftUI

struct VisitPrepView: View {
    @StateObject private var viewModel = VisitPrepViewModel()
    
    // Receive these from the view that presents this sheet
    let visits: [Visit]
    let medications: [Medication]
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Header
                VStack {
                    Text("Prepare for your next visit")
                        .font(.largeTitle).bold()
                        .multilineTextAlignment(.center)
                    Text("Your AI assistant has generated key discussion points for your upcoming appointment.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // Upcoming Visit Info Card
                VStack(alignment: .leading, spacing: 10) {
                    Text("UPCOMING APPOINTMENT")
                        .font(.caption).bold()
                        .foregroundColor(.secondary)
                    HStack {
                        Image(systemName: "calendar")
                            .font(.title)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(viewModel.upcomingVisit.specialty)
                                .font(.title2).bold()
                            Text(viewModel.upcomingVisit.date)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Prep Points Section
                if viewModel.isLoading {
                    ProgressView("Generating points...")
                        .padding(.top, 50)
                } else if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    List {
                        Section(header: Text("Key Discussion Points").font(.headline)) {
                            ForEach(viewModel.prepPoints, id: \.self) { point in
                                HStack(alignment: .top) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .padding(.top, 4)
                                    Text(point)
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    await viewModel.generatePreparationPoints(visits: visits, medications: medications)
                }
            }
        }
    }
}
