//
//  MedicationViewModel.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/3/25.
//


// ViewModels/MedicationViewModel.swift
import Foundation
import Firebase
import FirebaseAuth
import Combine

enum MedicationFilterType {
    case all
    case active
}

class MedicationViewModel: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAddMedication = false
    @Published var selectedMedication: Medication?
    @Published var filterType: MedicationFilterType = .all
    
    private let firebaseService = OpenCareFirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties matching web app functionality
    var activeMedications: [Medication] {
        medications.filter { $0.isCurrentlyActive }
    }
    
    var inactiveMedications: [Medication] {
        medications.filter { !$0.isCurrentlyActive }
    }
    
    var filteredMedications: [Medication] {
        switch filterType {
        case .all:
            return medications
        case .active:
            return activeMedications
        }
    }
    
    var totalMedications: Int {
        medications.count
    }
    
    var totalActiveMedications: Int {
        activeMedications.count
    }
    
    var medicationsBySpecialty: [String: [Medication]] {
        // Group medications by the specialty they were prescribed in
        // This would require linking medications to visits
        Dictionary(grouping: medications) { _ in "General" }
    }
    
    init() {
        // Load medications when initialized
        Task {
            await loadMedicationsAsync()
        }
    }
    
    // MARK: - Load Medications
    @MainActor
    func loadMedicationsAsync() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedMedications = try await firebaseService.getAllUserMedications(userId: userId)
            self.medications = fetchedMedications
            NotificationManager.shared.scheduleMedicationReminders(for: self.activeMedications)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Create Medication
    @MainActor
    func createMedication(_ medication: Medication) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Check if medication already exists
            let exists = try await firebaseService.checkMedicationExists(userId: userId, medicationName: medication.name)
            if exists {
                errorMessage = "Medication '\(medication.name)' is already active"
                isLoading = false
                return
            }
            
            try await firebaseService.createMedication(medication, userId: userId)
            await loadMedicationsAsync() // Reload medications after creation
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Update Medication
    @MainActor
    func updateMedication(_ medication: Medication) async {
        guard let medicationId = medication.id else {
            errorMessage = "Medication ID not found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Convert Medication to dictionary for update
            var updates: [String: Any] = [:]
            
            updates["name"] = medication.name.lowercased()
            updates["dosage"] = medication.dosage
            updates["frequency"] = medication.frequency
            if let timing = medication.timing {
                updates["timing"] = timing
            }
            if let route = medication.route {
                updates["route"] = route
            }
            if let laterality = medication.laterality {
                updates["laterality"] = laterality
            }
            if let duration = medication.duration {
                updates["duration"] = duration
            }
            if let instructions = medication.instructions {
                updates["instructions"] = instructions
            }
            if let fullInstructions = medication.fullInstructions {
                updates["fullInstructions"] = fullInstructions
            }
            
            try await firebaseService.updateMedication(medicationId: medicationId, updates: updates)
            await loadMedicationsAsync() // Reload medications after update
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Discontinue Medication
    @MainActor
    func discontinueMedication(_ medication: Medication, reason: String? = nil) async {
        guard let medicationId = medication.id else {
            errorMessage = "Medication ID not found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await firebaseService.discontinueMedication(medicationId: medicationId, reason: reason)
            await loadMedicationsAsync() // Reload medications after discontinuation
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Reactivate Medication
    @MainActor
    func reactivateMedication(_ medication: Medication) async {
        guard let medicationId = medication.id else {
            errorMessage = "Medication ID not found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var updates: [String: Any] = [:]
            updates["isActive"] = true
            updates["discontinuationReason"] = nil
            updates["discontinuedDate"] = nil
            
            try await firebaseService.updateMedication(medicationId: medicationId, updates: updates)
            await loadMedicationsAsync() // Reload medications after reactivation
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Delete Medication
    @MainActor
    func deleteMedication(_ medication: Medication) async {
        guard let medicationId = medication.id else {
            errorMessage = "Medication ID not found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await firebaseService.deleteMedication(medicationId)
            
            // Remove from local array
            medications.removeAll { $0.id == medicationId }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Get Medication by Name
    func getMedicationByName(_ name: String) async -> Medication? {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return nil
        }
        
        do {
            return try await firebaseService.getMedicationByName(userId: userId, medicationName: name)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Get Medication History
    func getMedicationHistory(_ medicationId: String) async -> [MedicationAction] {
        do {
            return try await firebaseService.getMedicationHistory(medicationId: medicationId)
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }
    
    // MARK: - Process Medication Actions from Visit
    @MainActor
    func processMedicationActions(_ actions: [MedicationAction], visitId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            for action in actions {
                // Record the medication action
                try await firebaseService.recordMedicationAction(action)
                
                // Handle different action types
                switch action.action {
                case .start:
                    // Create new medication if it doesn't exist
                    if let existingMed = await getMedicationByName(action.medicationName) {
                        // Medication already exists, update if needed
                        if let newInstructions = action.newInstructions {
                            var updatedMed = existingMed
                            updatedMed.fullInstructions = newInstructions
                            await updateMedication(updatedMed)
                        }
                    } else {
                        // Create new medication
                        var newMedication = Medication(
                            id: nil,
                            userId: nil,
                            name: action.medicationName,
                            dosage: "As prescribed",
                            frequency: "As prescribed",
                            timing: nil,
                            route: nil,
                            laterality: nil,
                            duration: nil,
                            instructions: nil,
                            fullInstructions: action.newInstructions ?? "Take as prescribed",
                            isActive: true,
                            discontinuationReason: nil,
                            createdAt: nil,
                            updatedAt: nil,
                            discontinuedDate: nil
                        )
                        
                        await createMedication(newMedication)
                    }
                    
                case .stop:
                    // Discontinue medication
                    if let existingMed = await getMedicationByName(action.medicationName) {
                        await discontinueMedication(existingMed, reason: action.reason)
                    }
                    
                case .modify:
                    // Update medication instructions
                    if let existingMed = await getMedicationByName(action.medicationName) {
                        var updatedMed = existingMed
                        updatedMed.fullInstructions = action.newInstructions ?? existingMed.fullInstructions
                        await updateMedication(updatedMed)
                    }
                    
                case .continued:
                    // No action needed for continued medications
                    break
                }
            }
            
            await loadMedicationsAsync() // Reload medications after processing actions
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Filter Medications
    func filterMedications(status: String? = nil, searchText: String? = nil) -> [Medication] {
        var filtered = medications
        
        if let status = status {
            switch status {
            case "Active":
                filtered = filtered.filter { $0.isCurrentlyActive }
            case "Inactive":
                filtered = filtered.filter { !$0.isCurrentlyActive }
            default:
                break
            }
        }
        
        if let searchText = searchText, !searchText.isEmpty {
            filtered = filtered.filter { medication in
                medication.name.localizedCaseInsensitiveContains(searchText) ||
                medication.dosage.localizedCaseInsensitiveContains(searchText) ||
                medication.frequency.localizedCaseInsensitiveContains(searchText) ||
                (medication.fullInstructions?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return filtered
    }
    
    // MARK: - Clear Error
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    func loadMedications() {
        Task {
            await loadMedicationsAsync()
        }
    }
    
    func saveMedication(_ medication: Medication) {
        Task {
            await createMedication(medication)
        }
    }
    
    func updateMedication(_ medication: Medication) {
        Task {
            await updateMedication(medication)
        }
    }
    
    func deleteMedication(_ medication: Medication) {
        Task {
            await deleteMedication(medication)
        }
    }
}
