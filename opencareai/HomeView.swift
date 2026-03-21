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
                    .environmentObject(userViewModel)
            }
            .onAppear {
                Task {
                    await visitViewModel.loadVisitsAsync()
                    await statsViewModel.fetchStats()
                    await userViewModel.fetchUserProfile()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - New Visit Recording View
// Web parity for this flow lives at:
// `/Users/gurpalvirdi/OpenCare/public/new-visit.html` (repo root: `/Users/gurpalvirdi/OpenCare`).
struct NewVisitView: View {
    @EnvironmentObject var visitViewModel: VisitViewModel
    @EnvironmentObject var audioRecorder: AudioRecorder
    @EnvironmentObject var userViewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingMedicationVerification = false
    @State private var showChronicConditionsSheet = false
    @State private var chronicConditionsPromptItems: [ChronicConditionPromptItem] = []
    @State private var showingProcessingSteps = false
    @State private var currentProcessingStep = 0
    @State private var detectedMedications: [Medication] = []
    @State private var detectedMedicationActions: [MedicationAction] = []
    @State private var currentStep: ProcessingStep = .ready
    
    // MARK: - Test input (Skip Recording) — parity with `new-visit.html` test card; field is not cleared by `clearVisitDraftState()`.
    @State private var testTranscript: String = ""
    /// Matches web discard: `statusEl.textContent = 'Visit discarded. Ready to record.'`
    @State private var idleStatusMessage: String?
    /// Recreate `MedicationVerificationView` when opening a new verification pass (stable state vs Firestore-sized action lists).
    @State private var medicationVerificationSession = UUID()
    
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
                    
                    // Header (web: `<h1>Record New Visit</h1>` + Step 1 card)
                    VStack(spacing: 8) {
                        Image(systemName: currentStep.icon)
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                        
                        Text("Record New Visit")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Step 1: Record Audio")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
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
                    
                    // MARK: - Test Input — web order: Step 1 card, then `#testInputCard`, then Step 2
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🧪 Test Input (Skip Recording)")
                            .font(.headline)
                        Text("Paste a transcript below to test summarization and medication extraction without recording audio.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $testTranscript)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        HStack(spacing: 12) {
                            Button(action: submitTestTranscript) {
                                Text("🧠 Process Transcript")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(testTranscript.isEmpty ? Color.orange.opacity(0.5) : Color.orange)
                                    .cornerRadius(10)
                            }
                            .disabled(testTranscript.isEmpty || visitViewModel.isLoading)
                            Button("Clear") {
                                testTranscript = ""
                            }
                            .buttonStyle(.bordered)
                            .disabled(testTranscript.isEmpty)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Step 2: Transcribe & Review (web `#transcript` — always visible with placeholder)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Step 2: Transcribe & Review")
                            .font(.headline)
                        ScrollView {
                            Text(visitViewModel.transcript.isEmpty
                                 ? "Your live transcription will appear here..."
                                 : visitViewModel.transcript)
                                .font(.body)
                                .foregroundColor(visitViewModel.transcript.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 100, maxHeight: 220)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Step 3 summary first, then medication verification (matches web `#summaryCard` layout order)
                    if let summary = visitViewModel.visitSummary {
                        NewVisitSummaryView(
                            summary: summary,
                            showPrimaryActions: !showingMedicationVerification,
                            onSave: {
                                Task {
                                    await visitViewModel.saveVisitFromSummary()
                                    dismiss()
                                }
                            },
                            onDiscard: {
                                clearVisitDraftState(afterDiscard: true)
                            }
                        )
                    }
                    
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
                                idleStatusMessage = "Medication editing mode: Edit medications above, then tap \"Confirm & Save Visit\" when ready."
                            },
                            onRemoveMedicationAction: { index in
                                guard detectedMedicationActions.indices.contains(index) else { return }
                                detectedMedicationActions.remove(at: index)
                            }
                        )
                        .id(medicationVerificationSession)
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
                        clearVisitDraftState()
                        testTranscript = ""
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showChronicConditionsSheet, onDismiss: {
            openMedicationVerificationIfNeeded()
        }) {
            ChronicConditionsMergeSheet(
                items: $chronicConditionsPromptItems,
                isPresented: $showChronicConditionsSheet,
                onMerge: { selected in
                    await userViewModel.mergeChronicConditionsFromVisit(selected)
                }
            )
        }
        .navigationViewStyle(.stack)
    }
    
    /// Clears pending visit/summary/medication UI (matches web `clearDraftState()`; does not clear the test transcript field).
    private func clearVisitDraftState(afterDiscard: Bool = false) {
        idleStatusMessage = nil
        visitViewModel.resetRecording()
        showingMedicationVerification = false
        detectedMedications = []
        detectedMedicationActions = []
        showingProcessingSteps = false
        currentStep = .ready
        showChronicConditionsSheet = false
        chronicConditionsPromptItems = []
        if afterDiscard {
            idleStatusMessage = "Visit discarded. Ready to record."
        }
    }
    
    /// After summary is ready: offer profile merge for new chronic conditions (web `showChronicConditionsModal`), then medication verification.
    private func openMedicationVerificationIfNeeded() {
        guard let summary = visitViewModel.visitSummary else { return }
        let prepared = MedicationNameMatcher.medicationsAndActionsForNewVisitVerification(
            medications: summary.medications,
            medicationActions: summary.medicationActions
        )
        detectedMedications = prepared.0
        detectedMedicationActions = prepared.1
        if !detectedMedications.isEmpty || !detectedMedicationActions.isEmpty {
            medicationVerificationSession = UUID()
            showingMedicationVerification = true
        }
    }
    
    private func processAfterSummaryReady() async {
        await userViewModel.fetchUserProfile()
        guard let summary = visitViewModel.visitSummary else { return }
        if summary.chronicConditions.isEmpty {
            openMedicationVerificationIfNeeded()
            return
        }
        let items = ChronicConditionsMergeSheet.buildItems(from: summary.chronicConditions, profile: userViewModel.user.chronicConditions)
        if items.contains(where: { $0.isNew }) {
            chronicConditionsPromptItems = items
            showChronicConditionsSheet = true
        } else {
            openMedicationVerificationIfNeeded()
        }
    }
    
    private func handleRecordingAction() {
        if audioRecorder.isRecording {
            // Stop recording and process
            if let audioData = audioRecorder.stopRecording() {
                Task { @MainActor in
                    await processAudioWithSteps(audioData)
                }
            }
        } else {
            // Start a fresh recording (web: `clearDraftState` before capture; test paste field left intact)
            clearVisitDraftState()
            Task {
                await audioRecorder.startRecording()
            }
        }
    }
    
    @MainActor
    private func processAudioWithSteps(_ audioData: Data) async {
        clearVisitDraftState()
        currentStep = .transcribing
        showingProcessingSteps = true
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
        await processAfterSummaryReady()
        
        currentStep = .complete
        showingProcessingSteps = false
    }
    
    private func processMedicationVerification(medications: [Medication], actions: [MedicationAction]) async {
        visitViewModel.applyVerifiedMedicationData(medications: medications, medicationActions: actions)
        showingMedicationVerification = false
        idleStatusMessage = "Medications confirmed. Use \"Confirm & Save Visit\" to finish."
    }
    
    /// Submit typed transcript for testing (skips audio recording)
    private func submitTestTranscript() {
        let trimmed = testTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        clearVisitDraftState()
        
        // Show processing UI
        currentStep = .transcribing
        showingProcessingSteps = true
        
        Task { @MainActor in
            idleStatusMessage = "Processing test transcript..."
            // Step 1: Transcribing (simulated - we already have the text)
            currentStep = .transcribing
            visitViewModel.transcript = trimmed
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
            
            // Step 2: Analyzing
            currentStep = .analyzing
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
            
            // Step 3: Extracting medications
            currentStep = .extractingMedications
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // Step 4: Generating summary
            currentStep = .generatingSummary
            
            // Actually process the transcript (skip transcription API call)
            await visitViewModel.generateSummaryFromTranscript()
            await processAfterSummaryReady()
            
            currentStep = .complete
            showingProcessingSteps = false
            idleStatusMessage = nil
        }
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
        } else if let idle = idleStatusMessage {
            return idle
        } else if visitViewModel.visitSummary != nil {
            return "Summary generated successfully!"
        } else {
            return "Ready to record."
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
    var onRemoveMedicationAction: ((Int) -> Void)?
    
    @State private var editableMedications: [Medication]
    @State private var confirmedActions: Set<Int> = []
    
    init(
        medications: [Medication],
        medicationActions: [MedicationAction],
        onConfirm: @escaping ([Medication], [MedicationAction]) -> Void,
        onEdit: @escaping ([Medication]) -> Void,
        onRemoveMedicationAction: ((Int) -> Void)? = nil
    ) {
        self.medications = medications
        self.medicationActions = medicationActions
        self.onConfirm = onConfirm
        self.onEdit = onEdit
        self.onRemoveMedicationAction = onRemoveMedicationAction
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
            
            if !medicationActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Medication Actions to Process:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.1, green: 0.46, blue: 0.82))
                    
                    ForEach(Array(medicationActions.enumerated()), id: \.offset) { index, action in
                        MedicationActionRow(
                            action: action,
                            isConfirmed: confirmedActions.contains(index),
                            onConfirmDiscontinue: { confirmedActions.insert(index) },
                            onRemoveAction: action.action.isStopLike
                                ? { onRemoveMedicationAction?(index) }
                                : nil
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
            
            // Button order matches web `.verification-actions`: Confirm first, then Edit
            HStack(spacing: 12) {
                Button("✅ Confirm Medications") {
                    let mergedActions: [MedicationAction] = medicationActions.enumerated().compactMap { index, action in
                        if action.action.isStopLike {
                            return confirmedActions.contains(index) ? action : nil
                        }
                        return action
                    }
                    onConfirm(editableMedications, mergedActions)
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasUnconfirmedStopActions())
                
                Button("✏️ Edit Medications") {
                    onEdit(editableMedications)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemYellow).opacity(0.1))
        .cornerRadius(12)
        .onChange(of: medicationActions.count) { _, _ in
            confirmedActions = []
        }
        .onAppear {
            editableMedications = medications
        }
    }
    
    private func hasUnconfirmedStopActions() -> Bool {
        medicationActions.enumerated().contains { index, action in
            action.action.isStopLike && !confirmedActions.contains(index)
        }
    }
}

struct MedicationActionRow: View {
    let action: MedicationAction
    let isConfirmed: Bool
    let onConfirmDiscontinue: () -> Void
    /// Web `cancel-stop-btn`: removes the action from the visit (parent updates the list).
    var onRemoveAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(actionIcon)
                        Text("\(verbLabel): \(action.medicationName)")
                            .fontWeight(.semibold)
                        if action.action.isStopLike {
                            Text("(Confirmation Required)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if let reason = action.reason, !reason.isEmpty {
                        Text("Reason: \(reason)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let newInstr = action.newInstructions, !newInstr.isEmpty {
                        Text("New Instructions: \(newInstr)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            
            if action.action.isStopLike {
                if isConfirmed {
                    Text("✅ Confirmed for discontinuation")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.098, green: 0.53, blue: 0.33))
                } else {
                    HStack(spacing: 8) {
                        Button("✅ Confirm Discontinue") { onConfirmDiscontinue() }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)
                        if onRemoveAction != nil {
                            Button("❌ Cancel") { onRemoveAction?() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(action.action.isStopLike ? Color.yellow.opacity(0.2) : Color.blue.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    action.action.isStopLike ? Color.orange.opacity(0.6) : Color.blue.opacity(0.35),
                    lineWidth: 1
                )
        )
        .padding(.vertical, 2)
    }
    
    private var verbLabel: String {
        switch action.action {
        case .stop, .discontinue: return "Discontinue"
        case .start: return "Start"
        case .modify: return "Modify"
        case .continued: return "Continue"
        }
    }
    
    private var actionIcon: String {
        switch action.action {
        case .stop, .discontinue: return "⏹️"
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
    /// Web hides `#summaryActions` while `#medicationVerification` is visible.
    var showPrimaryActions: Bool = true
    let onSave: () -> Void
    let onDiscard: () -> Void
    
    @State private var showDiscardConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 3: Review AI Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                SummarySection(title: "Full Summary", content: summary.summary)
                SummarySection(title: "TL;DR (Short Summary)", content: summary.tldr)
                SummarySection(title: "Medical Specialty", content: summary.specialty)
                SummarySection(title: "Date of Visit", content: summary.date)
                
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
            
            if showPrimaryActions {
                VStack(spacing: 12) {
                    Button("✅ Confirm & Save Visit") {
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("🗑️ Discard") {
                        showDiscardConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .confirmationDialog(
            "Discard this visit?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { onDiscard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It won't be saved.")
        }
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
