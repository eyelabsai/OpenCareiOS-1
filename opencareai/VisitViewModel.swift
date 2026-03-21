// ViewModels/VisitViewModel.swift
import Foundation
import Firebase
import FirebaseAuth
import Combine

class VisitViewModel: ObservableObject {
    @Published var currentStep: RecordingStep = .ready
    @Published var progressValue: Double = 0.0
    @Published var visitSummary: VisitSummary?
    @Published var showingSuccess = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var transcript: String = "" // Add transcript property to match web app
    @Published var visits: [Visit] = [] // Add visits property back
    @Published var medicationViewModel = MedicationViewModel() // Add this property
    
    private let apiService = APIService.shared
    private let firebaseService = OpenCareFirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    enum RecordingStep {
        case ready
        case recording
        case processing
        case reviewing
        case completed
    }
    
    // Computed properties matching web app functionality
    var totalVisits: Int {
        visits.count
    }
    
    var recentVisits: [Visit] {
        Array(visits.prefix(5))
    }
    
    var visitsThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        return visits.filter { visit in
            guard let visitDate = visit.date else { return false }
            return visitDate >= startOfMonth
        }.count
    }
    
    var visitsBySpecialty: [String: [Visit]] {
        Dictionary(grouping: visits) { $0.specialty ?? "Unknown" }
    }
    
    var specialties: [String] {
        Array(Set(visits.compactMap { $0.specialty })).sorted()
    }
    
    init() {
        // Load visits when initialized
        Task {
            await loadVisitsAsync()
        }
    }
    
    // New-visit parity: `/Users/gurpalvirdi/OpenCare/public/new-visit.html`
    /// Shared save path aligned with web `saveVisitAndMedications`: warnings → create visit → stop/modify → add new meds.
    @MainActor
    private func persistVisitFromSummary(_ summary: VisitSummary, userId: String, transcript: String) async throws {
        let actions = summary.medicationActions
        if !actions.isEmpty {
            let warnings = await medicationViewModel.evaluateMedicationActionStopModifyWarnings(actions: actions)
            if !warnings.isEmpty {
                throw NSError(
                    domain: "OpenCare",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: warnings.joined(separator: "\n")]
                )
            }
        }
        let visitDate = VisitSummaryDate.resolvedDate(from: summary.date)
        let iso = VisitSummaryDate.isoDateString(from: visitDate)
        let setting = VisitSetting(rawValue: summary.setting ?? "clinic") ?? .clinic
        
        var visit = Visit()
        visit.userId = userId
        visit.date = visitDate
        visit.specialty = summary.specialty
        visit.summary = summary.summary
        visit.tldr = summary.tldr
        visit.medications = summary.medications
        visit.medicationActions = actions
        visit.chronicConditions = summary.chronicConditions
        visit.createdAt = Date()
        visit.updatedAt = Date()
        visit.setting = setting
        visit.isDischarge = summary.isDischarge ?? false
        visit.startedAt = Date()
        visit.transcript = transcript.isEmpty ? nil : transcript
        
        try await firebaseService.createVisit(visit, userId: userId)
        await medicationViewModel.applyStopAndModifyFromVisitActions(actions)
        for var med in summary.medications {
            med.startDate = visitDate
            med.visitDate = iso
            await medicationViewModel.createMedication(med)
        }
        await loadVisitsAsync()
    }
    
    // MARK: - Load Visits
    @MainActor
    func loadVisitsAsync() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedVisits = try await firebaseService.getUserVisits(userId: userId)
            self.visits = fetchedVisits
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Create Visit
    @MainActor
    func createVisit(_ visit: Visit) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let actions = visit.medicationActions ?? []
            if !actions.isEmpty {
                let warnings = await medicationViewModel.evaluateMedicationActionStopModifyWarnings(actions: actions)
                if !warnings.isEmpty {
                    errorMessage = warnings.joined(separator: "\n")
                    isLoading = false
                    return
                }
            }
            try await firebaseService.createVisit(visit, userId: userId)
            await medicationViewModel.applyStopAndModifyFromVisitActions(actions)
            if let meds = visit.medications {
                let visitDate = visit.date ?? Date()
                let iso = VisitSummaryDate.isoDateString(from: visitDate)
                for var med in meds {
                    med.startDate = visitDate
                    med.visitDate = iso
                    await medicationViewModel.createMedication(med)
                }
            }
            await loadVisitsAsync()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Process Visit with Audio
    @MainActor
    func processVisitWithAudio(audioData: Data, filename: String) async -> Visit? {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let visitSummary = try await apiService.processVisit(audioData: audioData, filename: filename)
            let transcript = visitSummary.transcript ?? ""
            try await persistVisitFromSummary(visitSummary, userId: userId, transcript: transcript)
            
            var newVisit = Visit()
            newVisit.userId = userId
            newVisit.summary = visitSummary.summary
            newVisit.tldr = visitSummary.tldr
            newVisit.specialty = visitSummary.specialty
            newVisit.medications = visitSummary.medications
            newVisit.medicationActions = visitSummary.medicationActions
            newVisit.chronicConditions = visitSummary.chronicConditions
            newVisit.date = VisitSummaryDate.resolvedDate(from: visitSummary.date)
            newVisit.setting = VisitSetting(rawValue: visitSummary.setting ?? "clinic")
            newVisit.isDischarge = visitSummary.isDischarge
            newVisit.transcript = transcript.isEmpty ? nil : transcript
            return newVisit
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Update Visit
    @MainActor
    func updateVisit(_ visit: Visit) async {
        guard let visitId = visit.id else {
            errorMessage = "Visit ID not found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Convert Visit to dictionary for update
            var updates: [String: Any] = [:]
            
            if let specialty = visit.specialty {
                updates["specialty"] = specialty
            }
            if let summary = visit.summary {
                updates["summary"] = summary
            }
            if let tldr = visit.tldr {
                updates["tldr"] = tldr
            }
            if let date = visit.date {
                updates["date"] = Timestamp(date: date)
            }
            if let medications = visit.medications {
                updates["medications"] = medications
            }
            if let medicationActions = visit.medicationActions {
                updates["medicationActions"] = medicationActions
            }
            if let chronicConditions = visit.chronicConditions {
                updates["chronicConditions"] = chronicConditions
            }
            
            try await firebaseService.updateVisit(visitId: visitId, updates: updates)
            await loadVisitsAsync() // Reload visits after update
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Delete Visit
    @MainActor
    func deleteVisit(_ visit: Visit) async {
        guard let visitId = visit.id else {
            errorMessage = "Visit ID not found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await firebaseService.deleteVisit(visitId)
            
            // Remove from local array
            visits.removeAll { $0.id == visitId }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Get Visit by ID
    func getVisitById(_ visitId: String) async -> Visit? {
        do {
            return try await firebaseService.getVisitById(visitId: visitId)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Filter Visits
    func filterVisits(specialty: String? = nil, timeframe: String? = nil) -> [Visit] {
        var filtered = visits
        
        if let specialty = specialty, specialty != "All" {
            filtered = filtered.filter { $0.specialty == specialty }
        }
        
        if let timeframe = timeframe, timeframe != "All" {
            let calendar = Calendar.current
            let now = Date()
            
            switch timeframe {
            case "This Week":
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                filtered = filtered.filter { visit in
                    guard let visitDate = visit.date else { return false }
                    return visitDate >= startOfWeek
                }
            case "This Month":
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                filtered = filtered.filter { visit in
                    guard let visitDate = visit.date else { return false }
                    return visitDate >= startOfMonth
                }
            case "This Year":
                let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
                filtered = filtered.filter { visit in
                    guard let visitDate = visit.date else { return false }
                    return visitDate >= startOfYear
                }
            default:
                break
            }
        }
        
        return filtered
    }
    
    // MARK: - Clear Error
    func clearError() {
        errorMessage = nil
    }
    
    /// Clears the in-progress summary so a new recording or processing pass does not show stale content.
    @MainActor
    func clearPendingSummary() {
        visitSummary = nil
        transcript = ""
        errorMessage = nil
    }
    
    // MARK: - Summary Generation
    @MainActor
    func generateSummaryFromTranscript() async {
        guard !transcript.isEmpty else { return }
        
        do {
            var built = try await apiService.summarizeTranscriptWithVerification(transcript).0
            built.transcript = transcript
            self.visitSummary = built
        } catch {
            errorMessage = "Failed to generate summary: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Save Visit
    @MainActor
    func saveCurrentVisit() async {
        guard let summary = visitSummary else { return }
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let tx = summary.transcript ?? transcript
            try await persistVisitFromSummary(summary, userId: userId, transcript: tx)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    func loadVisits() {
        Task {
            await loadVisitsAsync()
        }
    }
    
    func saveVisit(_ visit: Visit) {
        Task {
            await createVisit(visit)
        }
    }
    
    func deleteVisit(_ visit: Visit) {
        Task {
            await deleteVisit(visit)
        }
    }
    
    // MARK: - Process Audio Recording (without auto-saving)
    @MainActor
    func processAudioRecording(_ audioData: Data) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        print("🔊 Starting audio processing...")
        print("🔊 Audio data size: \(audioData.count) bytes")
        
        isLoading = true
        errorMessage = nil
        progressValue = 0.0
        
        do {
            // Step 1: Transcribe audio
            print("🔊 Step 1: Transcribing audio...")
            progressValue = 0.3
            let transcriptionResponse = try await apiService.transcribeAudio(audioData: audioData, filename: "recording.m4a")
            
            print("🔊 Transcription response: \(transcriptionResponse)")
            
            guard let transcriptText = transcriptionResponse.transcript else {
                errorMessage = "No transcript received"
                isLoading = false
                return
            }
            
            print("🔊 Transcript received: \(transcriptText)")
            transcript = transcriptText
            progressValue = 0.6
            
            // Step 2: Summarize transcript
            print("🔊 Step 2: Summarizing transcript...")
            var built = try await apiService.summarizeTranscriptWithVerification(transcriptText).0
            built.transcript = transcriptText
            progressValue = 0.9
            
            print("🔊 Summarization response received: \(built.summary.prefix(80))…")
            
            // Step 3: VisitSummary (DO NOT SAVE YET)
            self.visitSummary = built
            
            print("🔊 Visit summary created: \(self.visitSummary?.summary ?? "No summary")")
            
            progressValue = 1.0
            currentStep = .reviewing
            
        } catch {
            print("❌ Error during audio processing: \(error)")
            errorMessage = error.localizedDescription
            currentStep = .ready
        }
        
        isLoading = false
    }
    
    // MARK: - Save Visit (explicit save action)
    @MainActor
    func saveVisitFromSummary() async {
        guard let summary = visitSummary else {
            errorMessage = "No visit summary to save"
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let tx = summary.transcript ?? transcript
            try await persistVisitFromSummary(summary, userId: userId, transcript: tx)
            currentStep = .completed
            showingSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Merge medication verification edits into the pending summary before explicit save (web: confirm then save).
    @MainActor
    func applyVerifiedMedicationData(medications: [Medication], medicationActions: [MedicationAction]) {
        guard var summary = visitSummary else { return }
        summary.medications = medications
        summary.medicationActions = medicationActions
        visitSummary = summary
    }
    
    func resetRecording() {
        progressValue = 0.0
        currentStep = .ready
        visitSummary = nil
        transcript = "" // Reset transcript
        showingSuccess = false
        errorMessage = nil
        isLoading = false
    }
}
