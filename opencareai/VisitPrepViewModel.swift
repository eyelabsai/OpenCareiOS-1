//
//  VisitPrepViewModel.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/21/25.
//



import Foundation

@MainActor
class VisitPrepViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var prepPoints: [String] = []
    @Published var errorMessage: String?
    
    // In a real app, you would fetch this from a data source.
    // For this example, we'll use a sample upcoming visit.
    @Published var upcomingVisit: (specialty: String, date: String) = ("Cardiology", "Friday, July 25th")
    
    private let apiService = APIService.shared
    private let healthKitManager = HealthKitManager.shared
    
    func generatePreparationPoints(visits: [Visit], medications: [Medication]) async {
        isLoading = true
        errorMessage = nil
        prepPoints = []

        // 1. Construct the detailed context string
        var context = "--- User's Health Context ---\n"
        
        // Add upcoming visit info
        context += "Upcoming Appointment: \(upcomingVisit.specialty) on \(upcomingVisit.date).\n"
        
        // Add recent visits (last 3)
        if !visits.isEmpty {
            context += "\nRecent Medical Visits:\n"
            for visit in visits.prefix(3) {
                context += "- \(visit.formattedDate) (\(visit.specialty ?? "N/A")): \(visit.tldr ?? "No summary").\n"
            }
        }
        
        // Add active medications
        if !medications.isEmpty {
            context += "\nCurrent Medications:\n"
            for medication in medications where medication.isCurrentlyActive {
                context += "- \(medication.name): \(medication.formattedInstructions).\n"
            }
        }
        
        // 2. Construct the specific question for the AI
        let question = """
        Based on the provided health context, generate a short, bulleted list of 3-4 key preparation points for my upcoming doctor's visit.
        Each point should be a clear, actionable question or statement for me to discuss with my doctor.
        Focus on medication changes, new or recurring symptoms, and follow-up actions.
        """

        // 3. Call the API
        do {
            let response = try await apiService.askHealthAssistant(question: question, context: context)
            guard let answer = response.answer else {
                throw APIError.assistantFailed("No response received from AI.")
            }
            
            // 4. Parse the bulleted list response
            self.prepPoints = answer.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "- ", with: "") }
                .filter { !$0.isEmpty }

        } catch {
            self.errorMessage = error.localizedDescription
            print("Error generating visit prep: \(error)")
        }
        
        isLoading = false
    }
}
