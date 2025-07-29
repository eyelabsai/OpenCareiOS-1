//
//  HealthReportView.swift
//  opencareai
//


import SwiftUI

struct HealthReportView: View {
    @ObservedObject var userViewModel: UserViewModel
    @ObservedObject var visitViewModel: VisitViewModel
    @ObservedObject var medicationViewModel: MedicationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Report Header
            VStack(alignment: .leading) {
                Text("Health Report")
                    .font(.largeTitle).bold()
                Text("Generated on \(Date().formatted(date: .long, time: .shortened))")
                    .font(.subheadline).foregroundColor(.secondary)
            }

            Divider()

            // Personal Information
            Section(header: Text("Personal Information").font(.title2).bold()) {
                VStack(alignment: .leading, spacing: 8) {
                    ReportRow(label: "Name", value: userViewModel.user.fullName)
                    ReportRow(label: "Date of Birth", value: userViewModel.user.dob)
                    ReportRow(label: "Contact", value: userViewModel.user.phoneNumber)
                }
            }
            
            // Medical Conditions & Allergies
            Section(header: Text("Key Medical Information").font(.title2).bold()) {
                VStack(alignment: .leading, spacing: 8) {
                    ReportRow(label: "Chronic Conditions", value: userViewModel.user.chronicConditions.joined(separator: ", "))
                    ReportRow(label: "Allergies", value: userViewModel.user.allergies.joined(separator: ", "))
                }
            }

            // Active Medications
            Section(header: Text("Active Medications").font(.title2).bold()) {
                if medicationViewModel.activeMedications.isEmpty {
                    Text("No active medications listed.").foregroundColor(.secondary)
                } else {
                    ForEach(medicationViewModel.activeMedications) { med in
                        VStack(alignment: .leading) {
                            Text(med.name).bold()
                            Text(med.formattedInstructions).font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.bottom, 5)
                    }
                }
            }

            // Recent Visits
            Section(header: Text("Recent Visit Summaries").font(.title2).bold()) {
                if visitViewModel.recentVisits.isEmpty {
                    Text("No recent visits recorded.").foregroundColor(.secondary)
                } else {
                    ForEach(visitViewModel.recentVisits) { visit in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(visit.specialty ?? "Visit").bold()
                                Spacer()
                                Text(visit.formattedDate).font(.caption)
                            }
                            Text(visit.tldr ?? "No summary available.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.bottom, 10)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
    }
}

// Helper view for a row in the report
struct ReportRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}
