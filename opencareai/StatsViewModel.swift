// ViewModels/StatsViewModel.swift
import Foundation
import Firebase
import FirebaseAuth
import Combine

class StatsViewModel: ObservableObject {
    @Published var currentMedications: [Medication] = []
    @Published var totalVisits: Int = 0
    @Published var visitsThisMonth: Int = 0
    @Published var totalMedications: Int = 0
    @Published var activeMedications: Int = 0
    @Published var specialties: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firebaseService = OpenCareFirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load stats when initialized
        Task {
            await fetchStats()
        }
    }
    
    // MARK: - Fetch Stats
    @MainActor
    func fetchStats() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch visits and medications concurrently
            async let visitsTask = firebaseService.getUserVisits(userId: userId)
            async let medicationsTask = firebaseService.getUserMedications(userId: userId)
            
            let (visits, medications) = try await (visitsTask, medicationsTask)
            
            // Update stats
            self.totalVisits = visits.count
            self.currentMedications = medications
            self.totalMedications = medications.count
            self.activeMedications = medications.filter { $0.isCurrentlyActive }.count
            
            // Calculate visits this month
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            
            self.visitsThisMonth = visits.filter { visit in
                guard let visitDate = visit.date else { return false }
                return visitDate >= startOfMonth
            }.count
            
            // Get unique specialties
            self.specialties = Array(Set(visits.compactMap { $0.specialty })).sorted()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Get Medication Stats
    func getMedicationStats() -> [String: Int] {
        var stats: [String: Int] = [:]
        
        // Count by route
        let routes = currentMedications.compactMap { $0.route }
        for route in Set(routes) {
            stats[route] = routes.filter { $0 == route }.count
        }
        
        // Count by frequency
        let frequencies = currentMedications.map { $0.frequency }
        for frequency in Set(frequencies) {
            stats[frequency] = frequencies.filter { $0 == frequency }.count
        }
        
        return stats
    }
    
    // MARK: - Get Visit Stats by Specialty
    func getVisitStatsBySpecialty() -> [String: Int] {
        // This would need to be implemented with actual visit data
        // For now, returning empty dictionary
        return [:]
    }
    
    // MARK: - Get Medication Compliance Stats
    func getMedicationComplianceStats() -> [String: Double] {
        // This would calculate compliance based on medication schedules
        // For now, returning placeholder data
        return [
            "On Time": 85.0,
            "Late": 10.0,
            "Missed": 5.0
        ]
    }
    
    // MARK: - Get Health Trends
    func getHealthTrends() -> [String: [Double]] {
        // This would calculate trends over time
        // For now, returning placeholder data
        return [
            "Visits": [2, 3, 1, 4, 2, 3, 1],
            "Medications": [5, 6, 4, 7, 5, 6, 4]
        ]
    }
    
    // MARK: - Get Recent Activity
    func getRecentActivity() -> [String: String] {
        // This would return recent activity summary
        // For now, returning placeholder data
        return [
            "Last Visit": "Cardiology - 2 days ago",
            "Last Medication Change": "Added Lisinopril - 1 week ago",
            "Next Appointment": "Primary Care - 2 weeks"
        ]
    }
    
    // MARK: - Clear Error
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    func loadStats() {
        Task {
            await fetchStats()
        }
    }
}