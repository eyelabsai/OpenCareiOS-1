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
    @StateObject private var userViewModel = UserViewModel()
    @Binding var selectedTab: Int
    
    @State private var showingNewVisit = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Personalized Welcome Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome, \(userViewModel.user.firstName.isEmpty ? "there" : userViewModel.user.firstName)!")
                            .font(.title)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("Ready to record your next visit?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    // Primary Action - Record Visit (Large, Prominent)
                    VStack(spacing: 16) {
                        Button(action: { showingNewVisit = true }) {
                            VStack(spacing: 12) {
                                Image(systemName: "mic.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white)
                                Text("Record New Visit")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Text("Tap to start recording your doctor's visit")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 24)

                    // Essential Quick Actions (Simplified)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Access")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.leading, 4)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            // Visit History
                            Button(action: { selectedTab = 1 }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "clock.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    Text("Visit History")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Medications
                            Button(action: { selectedTab = 2 }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "pills.fill")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                    Text("Medications")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)

                    // Simple Stats (Only Most Important)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Summary")
                                .font(.title2)
                                .fontWeight(.semibold)
                            .padding(.leading, 4)
                        
                        HStack(spacing: 16) {
                            SimpleStatCard(
                                title: "Total Visits",
                                value: "\(visitViewModel.totalVisits)",
                                icon: "calendar",
                                color: .blue
                            )
                            SimpleStatCard(
                                title: "Active Meds",
                                value: "\(statsViewModel.currentMedications.count)",
                                icon: "pills",
                                color: .orange
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNewVisit) {
                NewVisitView()
                    .environmentObject(visitViewModel)
                    .environmentObject(audioRecorder)
            }
            .onAppear {
                Task {
                    await visitViewModel.loadVisitsAsync()
                    await statsViewModel.fetchStats()
                    await userViewModel.fetchUserProfile()
                }
            }
        }
    }
}

// MARK: - New Visit Recording View  
struct NewVisitView: View {
    @EnvironmentObject var visitViewModel: VisitViewModel
    @EnvironmentObject var audioRecorder: AudioRecorder
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingMedicationVerification = false
    @State private var showingProcessingSteps = false
    @State private var currentProcessingStep = 0
    @State private var detectedMedications: [Medication] = []
    @State private var detectedMedicationActions: [MedicationAction] = []
    @State private var currentStep: ProcessingStep = .ready
    
    enum ProcessingStep {
        case ready, transcribing, analyzing, extractingMedications, generatingSummary, complete
        
        var title: String {
            switch self {
            case .ready: return "Ready to record"
            case .transcribing: return "Transcribing audio..."
            case .analyzing: return "Analyzing content..."
            case .extractingMedications: return "Extracting medications..."
            case .generatingSummary: return "Generating summary..."
            case .complete: return "Processing complete!"
            }
        }
        
        var icon: String {
            switch self {
            case .ready: return "mic.fill"
            case .transcribing: return "waveform"
            case .analyzing: return "brain.head.profile"
            case .extractingMedications: return "pills.fill"
            case .generatingSummary: return "doc.text.fill"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: currentStep.icon)
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                        
                        Text("Record Your Visit")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("💡 For longer visits (1+ minutes), speak clearly and pause between topics. The system can handle recordings up to 50MB.")
                                .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // AI Processing Steps (matching web app)
                    if showingProcessingSteps {
                        ProcessingStepsView(currentStep: currentStep)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }
                    
                    // Recording Status with enhanced feedback
                    if visitViewModel.isLoading {
                        VStack(spacing: 16) {
                            // Animated brain processing indicator
                            ZStack {
                                Circle()
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .trim(from: 0.0, to: visitViewModel.progressValue)
                                    .stroke(Color.blue, lineWidth: 4)
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 0.3), value: visitViewModel.progressValue)
                                
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                                    .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2) * 0.1)
                            }
                            
                            Text(currentStep.title)
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    // Recording Controls with enhanced UI
                    VStack(spacing: 20) {
                        // Main Recording Button
                        Button(action: handleRecordingAction) {
                            ZStack {
                                Circle()
                                    .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Circle()
                                            .stroke(audioRecorder.isRecording ? Color.red.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: audioRecorder.isRecording ? 8 : 0)
                                            .scaleEffect(audioRecorder.isRecording ? 1.3 : 1.0)
                                            .opacity(audioRecorder.isRecording ? 0 : 1)
                                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: audioRecorder.isRecording)
                                    )
                                
                                Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                        }
                        .scaleEffect(audioRecorder.isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: audioRecorder.isRecording)
                        .disabled(visitViewModel.isLoading)
                        
                        // Recording Info (matching web app)
                        if audioRecorder.isRecording {
                            VStack(spacing: 8) {
                                Text("Duration: \(formatTime(audioRecorder.recordingTime))")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                
                                Text("File size: ~\(estimateFileSize(audioRecorder.recordingTime)) KB")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("💡 Tip: For longer visits, speak clearly and pause between topics for better transcription.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .padding(.top, 4)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Status text
                        Text(getStatusText())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Medication Verification Section
                    if showingMedicationVerification {
                        MedicationVerificationView(
                            medications: detectedMedications,
                            medicationActions: detectedMedicationActions,
                            onConfirm: { confirmedMeds, confirmedActions in
                                Task {
                                    await processMedicationVerification(medications: confirmedMeds, actions: confirmedActions)
                                }
                            },
                            onEdit: { editedMeds in
                                detectedMedications = editedMeds
                            }
                        )
                    }
                    
                    // Visit Summary (enhanced layout)
                    if let summary = visitViewModel.visitSummary {
                        NewVisitSummaryView(
                            summary: summary,
                            onSave: {
                                Task {
                                    await visitViewModel.saveVisitFromSummary()
                                    dismiss()
                                }
                            }
                        )
                    }
                    
                    // Error Message with better styling
                    if let error = visitViewModel.errorMessage {
                        ErrorMessageView(message: error)
                    }
                }
                .padding()
            }
            .navigationTitle("New Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if audioRecorder.isRecording {
                            _ = audioRecorder.stopRecording()
                        }
                        visitViewModel.resetRecording()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func handleRecordingAction() {
        if audioRecorder.isRecording {
            // Stop recording and process
            if let audioData = audioRecorder.stopRecording() {
                currentStep = .transcribing
                showingProcessingSteps = true
                
                Task {
                    await processAudioWithSteps(audioData)
                }
            }
        } else {
            // Start recording
            currentStep = .ready
            Task {
                await audioRecorder.startRecording()
            }
        }
    }
    
    private func processAudioWithSteps(_ audioData: Data) async {
        // Step 1: Transcribing
        currentStep = .transcribing
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        // Step 2: Analyzing
        currentStep = .analyzing
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Step 3: Extracting medications
        currentStep = .extractingMedications
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Step 4: Generating summary
        currentStep = .generatingSummary
        
        // Actually process the audio
        await visitViewModel.processAudioRecording(audioData)
        
        // Check if we have medications to verify
        if let summary = visitViewModel.visitSummary {
            detectedMedications = summary.medications
            // Convert medication action strings to MedicationAction objects
            detectedMedicationActions = summary.medicationActions.compactMap { actionString in
                MedicationAction(
                    id: UUID().uuidString,
                    visitId: nil,
                    medicationId: nil,
                    action: MedicationActionType(rawValue: actionString) ?? .continued,
                    medicationName: actionString,
                    genericReference: nil,
                    reason: nil,
                    newInstructions: nil,
                    createdAt: Date()
                )
            }
            
            if !detectedMedications.isEmpty || !detectedMedicationActions.isEmpty {
                showingMedicationVerification = true
            }
        }
        
        currentStep = .complete
        showingProcessingSteps = false
    }
    
    private func processMedicationVerification(medications: [Medication], actions: [MedicationAction]) async {
        // Save the verified medications and actions
        // This would integrate with your medication verification logic
        showingMedicationVerification = false
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func estimateFileSize(_ timeInterval: TimeInterval) -> Int {
        // Estimate ~16KB per second for audio
        return Int(timeInterval * 16)
    }
    
    private func getStatusText() -> String {
        if audioRecorder.isRecording {
            return "Recording in progress..."
        } else if visitViewModel.isLoading {
            return currentStep.title
        } else if visitViewModel.visitSummary != nil {
            return "Processing complete! Review your visit summary below."
        } else {
            return "Tap the microphone to start recording your medical visit"
        }
    }
}

// MARK: - Supporting Views for Enhanced NewVisitView

struct ProcessingStepsView: View {
    let currentStep: NewVisitView.ProcessingStep
    
    private let steps: [NewVisitView.ProcessingStep] = [
        .transcribing, .analyzing, .extractingMedications, .generatingSummary
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("AI Processing Your Visit")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text("Analyzing transcript and extracting key medical information...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(steps, id: \.self) { step in
                    HStack {
                        stepIcon(for: step)
                        Text(step.title)
                            .font(.subheadline)
                            .foregroundColor(stepColor(for: step))
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private func stepIcon(for step: NewVisitView.ProcessingStep) -> some View {
        if stepCompleted(step) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else if step == currentStep {
            ProgressView()
                .scaleEffect(0.8)
        } else {
            Image(systemName: "circle")
                .foregroundColor(.secondary)
        }
    }
    
    private func stepColor(for step: NewVisitView.ProcessingStep) -> Color {
        if stepCompleted(step) {
            return .green
        } else if step == currentStep {
            return .blue
        } else {
            return .secondary
        }
    }
    
    private func stepCompleted(_ step: NewVisitView.ProcessingStep) -> Bool {
        let stepIndex = steps.firstIndex(of: step) ?? 0
        let currentIndex = steps.firstIndex(of: currentStep) ?? 0
        return stepIndex < currentIndex
    }
}

struct MedicationVerificationView: View {
    let medications: [Medication]
    let medicationActions: [MedicationAction]
    let onConfirm: ([Medication], [MedicationAction]) -> Void
    let onEdit: ([Medication]) -> Void
    
    @State private var editableMedications: [Medication]
    @State private var confirmedActions: Set<Int> = []
    
    init(medications: [Medication], medicationActions: [MedicationAction], onConfirm: @escaping ([Medication], [MedicationAction]) -> Void, onEdit: @escaping ([Medication]) -> Void) {
        self.medications = medications
        self.medicationActions = medicationActions
        self.onConfirm = onConfirm
        self.onEdit = onEdit
        self._editableMedications = State(initialValue: medications)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Medication Verification")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Please review the medications and actions detected from your visit:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Show medication actions that need confirmation
            if !medicationActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Medication Actions:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(Array(medicationActions.enumerated()), id: \.offset) { index, action in
                        MedicationActionRow(
                            action: action,
                            isConfirmed: confirmedActions.contains(index),
                            onConfirm: { confirmedActions.insert(index) },
                            onCancel: { confirmedActions.remove(index) }
                        )
                    }
                }
            }
            
            // Show detected medications
            if !editableMedications.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected Medications:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(Array(editableMedications.enumerated()), id: \.offset) { index, medication in
                        MedicationRow(medication: medication) { updatedMed in
                            editableMedications[index] = updatedMed
                        }
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Edit Medications") {
                    onEdit(editableMedications)
                }
                .buttonStyle(.bordered)
                
                Button("Confirm & Continue") {
                    let confirmedActionsArray = medicationActions.enumerated().compactMap { index, action in
                        confirmedActions.contains(index) ? action : nil
                    }
                    onConfirm(editableMedications, confirmedActionsArray)
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasUnconfirmedStopActions())
            }
        }
        .padding()
        .background(Color(.systemYellow).opacity(0.1))
        .cornerRadius(12)
    }
    
    private func hasUnconfirmedStopActions() -> Bool {
        return medicationActions.enumerated().contains { index, action in
            action.action == .stop && !confirmedActions.contains(index)
        }
    }
}

struct MedicationActionRow: View {
    let action: MedicationAction
    let isConfirmed: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(actionIcon)
                    Text("\(action.action.displayName): \(action.medicationName)")
                        .fontWeight(.medium)
                }
                
                if let reason = action.reason {
                    Text("Reason: \(reason)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if action.action == .stop {
                if isConfirmed {
                    Text("✅ Confirmed")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    HStack {
                        Button("Confirm") { onConfirm() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        
                        Button("Cancel") { onCancel() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var actionIcon: String {
        switch action.action {
        case .stop: return "⏹️"
        case .start: return "▶️"
        case .modify: return "✏️"
        case .continued: return "🔄"
        }
    }
}

struct MedicationRow: View {
    let medication: Medication
    let onUpdate: (Medication) -> Void
    
    @State private var editableMed: Medication
    
    init(medication: Medication, onUpdate: @escaping (Medication) -> Void) {
        self.medication = medication
        self.onUpdate = onUpdate
        self._editableMed = State(initialValue: medication)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Medication name", text: Binding(
                    get: { editableMed.name },
                    set: { 
                        editableMed.name = $0
                        onUpdate(editableMed)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                
                TextField("Dosage", text: Binding(
                    get: { editableMed.dosage },
                    set: { 
                        editableMed.dosage = $0
                        onUpdate(editableMed)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 100)
            }
            
            HStack {
                TextField("Frequency", text: Binding(
                    get: { editableMed.frequency },
                    set: { 
                        editableMed.frequency = $0
                        onUpdate(editableMed)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                
                TextField("Duration", text: Binding(
                    get: { editableMed.duration ?? "" },
                    set: { 
                        editableMed.duration = $0.isEmpty ? nil : $0
                        onUpdate(editableMed)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 100)
            }
            
            if let instructions = editableMed.fullInstructions, !instructions.isEmpty {
                Text("Instructions: \(instructions)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct NewVisitSummaryView: View {
    let summary: VisitSummary
    let onSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visit Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                SummarySection(title: "Summary", content: summary.summary)
                SummarySection(title: "Key Points", content: summary.tldr)
                SummarySection(title: "Specialty", content: summary.specialty)
                SummarySection(title: "Date", content: summary.date)
                
                if !summary.medications.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Medications (\(summary.medications.count))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(summary.medications, id: \.name) { medication in
                            Text("• \(medication.name) - \(medication.dosage) \(medication.frequency)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !summary.chronicConditions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chronic Conditions")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(summary.chronicConditions, id: \.self) { condition in
                            Text("• \(condition)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Button("Save Visit & Return to Dashboard") {
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SummarySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .foregroundColor(.red)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Simple Stat Card (for simplified home screen)
struct SimpleStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
