//
//  HealthAssistantViewModel.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/3/25.
//


// ViewModels/HealthAssistantViewModel.swift
import Foundation
import Firebase
import Combine
import FirebaseAuth

class HealthAssistantViewModel: ObservableObject {
    @Published var messages: [HealthAssistantMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentMessage = ""
    @Published var isTyping = false
    
    private let apiService = APIService.shared
    private let firebaseService = OpenCareFirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load previous messages when initialized
        Task {
            await loadMessagesAsync()
        }
    }
    
    // MARK: - Load Messages
    @MainActor
    func loadMessagesAsync() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedMessages = try await firebaseService.getHealthAssistantMessages(userId: userId)
            self.messages = fetchedMessages
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Send Message
    @MainActor
    func sendMessage(_ message: String) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        isTyping = true
        
        // Create user message
        var userMessage = HealthAssistantMessage(
            id: UUID().uuidString,
            userId: userId,
            message: message,
            response: "",
            timestamp: Date()
        )
        
        // Add user message to the list
        messages.append(userMessage)
        
        do {
            // Get context from recent visits and medications
            let context = await buildContext()
            
            // Send to API
            let response = try await apiService.askHealthAssistant(question: message, context: context)
            
            guard let answer = response.answer else {
                throw APIError.assistantFailed("No response received")
            }
            
            // Update the message with the response
            userMessage.response = answer
            
            // Save to Firebase
            try await firebaseService.saveHealthAssistantMessage(userMessage)
            
            // Update the message in the list
            if let index = messages.firstIndex(where: { $0.id == userMessage.id }) {
                messages[index] = userMessage
            }
            
        } catch {
            errorMessage = error.localizedDescription
            
            // Remove the message if it failed
            messages.removeAll { $0.id == userMessage.id }
        }
        
        isLoading = false
        isTyping = false
        currentMessage = ""
    }
    
    // MARK: - Build Context
    private func buildContext() async -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            return ""
        }
        
        var context = ""
        
        do {
            // Get recent visits
            let visits = try await firebaseService.getUserVisits(userId: userId)
            let recentVisits = Array(visits.prefix(3))
            
            if !recentVisits.isEmpty {
                context += "Recent Medical Visits:\n"
                for visit in recentVisits {
                    context += "- \(visit.specialty ?? "General"): \(visit.tldr ?? visit.summary ?? "No summary")\n"
                }
                context += "\n"
            }
            
            // Get active medications
            let medications = try await firebaseService.getUserMedications(userId: userId)
            
            if !medications.isEmpty {
                context += "Current Medications:\n"
                for medication in medications {
                    context += "- \(medication.name): \(medication.formattedInstructions)\n"
                }
                context += "\n"
            }
            
            // Get user profile for allergies and conditions
            let user = try await firebaseService.getUserData(userId: userId)
            
            if !user.allergies.isEmpty {
                context += "Allergies: \(user.allergies.joined(separator: ", "))\n"
            }
            
            if !user.chronicConditions.isEmpty {
                context += "Chronic Conditions: \(user.chronicConditions.joined(separator: ", "))\n"
            }
            
        } catch {
            // If context building fails, continue without it
            print("Failed to build context: \(error)")
        }
        
        return context
    }
    
    // MARK: - Clear Messages
    @MainActor
    func clearMessages() {
        messages.removeAll()
    }
    
    // MARK: - Delete Message
    @MainActor
    func deleteMessage(_ message: HealthAssistantMessage) async {
        guard let messageId = message.id else {
            errorMessage = "Message ID not found"
            return
        }
        
        do {
            try await firebaseService.deleteHealthAssistantMessage(messageId: messageId)
            messages.removeAll { $0.id == messageId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Get Message by ID
    func getMessageById(_ messageId: String) -> HealthAssistantMessage? {
        return messages.first { $0.id == messageId }
    }
    
    // MARK: - Search Messages
    func searchMessages(query: String) -> [HealthAssistantMessage] {
        guard !query.isEmpty else { return messages }
        
        return messages.filter { message in
            message.message.localizedCaseInsensitiveContains(query) ||
            message.response.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - Clear Error
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    func loadMessages() {
        Task {
            await loadMessagesAsync()
        }
    }
    
    func sendMessage(_ message: String) {
        Task {
            await sendMessage(message)
        }
    }
}

// MARK: - Firebase Service Extension for Health Assistant
extension OpenCareFirebaseService {
    func saveHealthAssistantMessage(_ message: HealthAssistantMessage) async throws {
        // Convert HealthAssistantMessage to dictionary manually
        var dict: [String: Any] = [
            "id": message.id ?? "",
            "userId": message.userId,
            "message": message.message,
            "response": message.response
        ]
        
        // Convert Date objects to Firestore Timestamps
        if let timestamp = message.timestamp {
            dict["timestamp"] = Timestamp(date: timestamp)
        }
        
        let db = OpenCareFirebaseService.shared.getFirestore()
        try await db.collection("health_assistant_messages").addDocument(data: dict)
    }
    
    func getHealthAssistantMessages(userId: String) async throws -> [HealthAssistantMessage] {
        let db = OpenCareFirebaseService.shared.getFirestore()
        let snapshot = try await db.collection("health_assistant_messages")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            var data = document.data()
            
            // Convert Firestore Timestamps to ISO8601 strings
            if let timestamp = data["timestamp"] as? Timestamp {
                data["timestamp"] = ISO8601DateFormatter().string(from: timestamp.dateValue())
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            var message = try OpenCareFirebaseService.shared.getJSONDecoder().decode(HealthAssistantMessage.self, from: jsonData)
            message.id = document.documentID
            return message
        }
    }
    
        func deleteHealthAssistantMessage(messageId: String) async throws {
        let db = OpenCareFirebaseService.shared.getFirestore()
        try await db.collection("health_assistant_messages").document(messageId).delete()
    }
}
