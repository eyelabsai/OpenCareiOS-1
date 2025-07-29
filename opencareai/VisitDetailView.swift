import SwiftUI

struct VisitDetailView: View {
    let visit: Visit
    @EnvironmentObject var visitViewModel: VisitViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    @State private var showingHealthAssistant = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    VisitHeaderView(visit: visit, showingHealthAssistant: $showingHealthAssistant, showingEditSheet: $showingEditSheet)
                    
                    VisitContentView(visit: visit)
                    
                    VisitActionButtonsView(
                        shareVisitSummary: shareVisitSummary,
                        exportToPDF: exportToPDF,
                        showingHealthAssistant: $showingHealthAssistant
                    )
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Visit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("Delete Visit", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    visitViewModel.deleteVisit(visit)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this visit? This action cannot be undone.")
            }
            .sheet(isPresented: $showingEditSheet) {
                EditVisitView(visit: visit)
                    .environmentObject(visitViewModel)
            }
            .sheet(isPresented: $showingHealthAssistant) {
                HealthAssistantView()
                    .environmentObject(visitViewModel)
            }
        }
    }
    
    private func shareVisitSummary() {
        var shareText = "Medical Visit Summary\n\n"
        shareText += "Specialty: \(visit.specialty ?? "Unknown")\n"
        shareText += "Date: \(visit.formattedDate)\n\n"
        
        if let tldr = visit.tldr {
            shareText += "Quick Summary: \(tldr)\n\n"
        }
        
        if let summary = visit.summary {
            shareText += "Full Summary: \(summary)\n\n"
        }
        
        if let medications = visit.medications, !medications.isEmpty {
            shareText += "Medications:\n"
            for medication in medications {
                shareText += "• \(medication.formattedInstructions)\n"
            }
        }
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func exportToPDF() {
        // PDF export functionality would be implemented here
        // For now, just show a placeholder
    }
}

// MARK: - Meta Data Item Component
struct MetaDataItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Enhanced Medication Item
struct EnhancedMedicationItem: View {
    let medication: Medication
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(medication.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Medication status label
                if medication.isActive ?? true {
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                } else {
                    Text("Inactive")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                // Dosage, frequency, timing, etc.
                VStack(alignment: .leading, spacing: 2) {
                    if !medication.dosage.isEmpty && medication.dosage != "Not specified" {
                        Text("Dosage: \(medication.dosage)")
                    }
                    if !medication.frequency.isEmpty && medication.frequency != "Not specified" {
                        Text("Frequency: \(medication.frequency)")
                    }
                    if let timing = medication.timing, !timing.isEmpty && timing != "Not specified" {
                        Text("Timing: \(timing)")
                    }
                    if let route = medication.route, !route.isEmpty && route != "Not specified" {
                        Text("Route: \(route)")
                    }
                    if let laterality = medication.laterality, !laterality.isEmpty && laterality != "Not specified" {
                        Text("Laterality: \(laterality)")
                    }
                    if let duration = medication.duration, !duration.isEmpty && duration != "Not specified" {
                        Text("Duration: \(duration)")
                    }
                    if let instructions = medication.fullInstructions, !instructions.isEmpty && instructions != "Not specified" {
                        Text(instructions)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(medication.formattedInstructions)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Edit Visit View
struct EditVisitView: View {
    let visit: Visit
    @EnvironmentObject var visitViewModel: VisitViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var specialty: String
    @State private var summary: String
    @State private var tldr: String
    
    init(visit: Visit) {
        self.visit = visit
        _specialty = State(initialValue: visit.specialty ?? "")
        _summary = State(initialValue: visit.summary ?? "")
        _tldr = State(initialValue: visit.tldr ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Visit Information") {
                    TextField("Specialty", text: $specialty)
                    
                    TextField("Quick Summary (TL;DR)", text: $tldr, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Full Summary") {
                    TextField("Visit Summary", text: $summary, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Edit Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        // Update visit with new data
        var updatedVisit = visit
        updatedVisit.specialty = specialty
        updatedVisit.summary = summary
        updatedVisit.tldr = tldr
        
        // Save to Firebase
        Task {
            // This would update the visit in Firebase
            // For now, just dismiss
            dismiss()
        }
    }
}

#Preview {
    let sampleVisit = Visit(
        id: "1",
        date: Date(),
        specialty: "Cardiology",
        summary: "Patient presented with chest pain. EKG was normal. Prescribed nitroglycerin for emergency use.",
        tldr: "Chest pain evaluation - normal EKG, prescribed nitroglycerin",
        medications: [
            Medication(
                name: "Nitroglycerin",
                dosage: "0.4mg",
                frequency: "as needed",
                fullInstructions: "0.4mg sublingual as needed for chest pain"
            )
        ]
    )
    
    VisitDetailView(visit: sampleVisit)
        .environmentObject(VisitViewModel())
}

// MARK: - Visit Header View
struct VisitHeaderView: View {
    let visit: Visit
    @Binding var showingHealthAssistant: Bool
    @Binding var showingEditSheet: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(visit.specialty ?? "Unknown Specialty")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(visit.formattedDate)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: { showingHealthAssistant = true }) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { showingEditSheet = true }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            HStack(spacing: 20) {
                if visit.medicationsCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "pills.fill")
                            .foregroundColor(.blue)
                        Text("\(visit.medicationsCount) medication(s)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                }
                
                if let chronicConditions = visit.chronicConditions, !chronicConditions.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("\(chronicConditions.count) condition(s)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(20)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Visit Content View
struct VisitContentView: View {
    let visit: Visit
    
    var body: some View {
        VStack(spacing: 24) {
            VisitMetaDataView(visit: visit)
            VisitSummaryView(visit: visit)
        }
    }
}

// MARK: - Visit Meta Data View
struct VisitMetaDataView: View {
    let visit: Visit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Visit Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 16) {
                    MetaDataItem(
                        label: "Specialty",
                        value: visit.specialty ?? "Not specified"
                    )
                    
                    MetaDataItem(
                        label: "Date",
                        value: visit.formattedDate
                    )
                    
                    if let medications = visit.medications, !medications.isEmpty {
                        MetaDataItem(
                            label: "Medications",
                            value: "\(medications.count) prescribed"
                        )
                    }
                    
                    if let chronicConditions = visit.chronicConditions, !chronicConditions.isEmpty {
                        MetaDataItem(
                            label: "Conditions",
                            value: "\(chronicConditions.count) noted"
                        )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            
            if let tldr = visit.tldr, !tldr.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Summary")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(tldr)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
        }
    }
}

// MARK: - Visit Summary View
struct VisitSummaryView: View {
    let visit: Visit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let summary = visit.summary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Visit Summary")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(summary)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
            
            if let medications = visit.medications, !medications.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Medications")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVStack(spacing: 12) {
                        ForEach(medications) { medication in
                            EnhancedMedicationItem(medication: medication)
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
        }
    }
}

// MARK: - Visit Action Buttons View
struct VisitActionButtonsView: View {
    let shareVisitSummary: () -> Void
    let exportToPDF: () -> Void
    @Binding var showingHealthAssistant: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            PrimaryButton("Share Visit Summary") {
                shareVisitSummary()
            }
            
            HStack(spacing: 12) {
                SecondaryButton(title: "Export to PDF") {
                    exportToPDF()
                }
                
                SecondaryButton(title: "Health Assistant") {
                    showingHealthAssistant = true
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}