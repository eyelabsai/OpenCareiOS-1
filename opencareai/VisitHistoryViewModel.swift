//
//  VisitHistoryViewModel.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/3/25.
//


// ViewModels/VisitHistoryViewModel.swift
import Foundation
import FirebaseAuth

@MainActor
class VisitHistoryViewModel: ObservableObject {
    @Published var visits: [Visit] = []
    @Published var filteredVisits: [Visit] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let firebaseService = OpenCareFirebaseService.shared
    private var currentFilter = "All"
    private var currentSearchQuery = ""
    
    func fetchVisits() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let userId = Auth.auth().currentUser?.uid ?? ""
            let fetchedVisits = try await firebaseService.getUserVisits(userId: userId)
            visits = fetchedVisits
            applyFilters()
        } catch {
            errorMessage = "Failed to fetch visits: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func filterVisits(by filter: String) {
        currentFilter = filter
        applyFilters()
    }
    
    func searchVisits(query: String) {
        currentSearchQuery = query
        applyFilters()
    }
    
    private func applyFilters() {
        var filtered = visits
        
        // Apply specialty filter
        if currentFilter != "All" {
            filtered = filtered.filter { $0.specialty == currentFilter }
        }
        
        // Apply search filter
        if !currentSearchQuery.isEmpty {
            filtered = filtered.filter { visit in
                (visit.specialty?.localizedCaseInsensitiveContains(currentSearchQuery) ?? false) ||
                (visit.summary?.localizedCaseInsensitiveContains(currentSearchQuery) ?? false) ||
                (visit.tldr?.localizedCaseInsensitiveContains(currentSearchQuery) ?? false) ||
                ((visit.medications ?? []).contains { $0.name.localizedCaseInsensitiveContains(currentSearchQuery) })
            }
        }
        
        filteredVisits = filtered
    }
    
    func deleteVisit(_ visit: Visit) async {
        guard let visitId = visit.id else { return }
        
        do {
            try await firebaseService.deleteVisit(visitId)
            // Remove from local arrays
            visits.removeAll { $0.id == visitId }
            applyFilters()
        } catch {
            errorMessage = "Failed to delete visit: \(error.localizedDescription)"
        }
    }
}
