// Services/APIService.swift
import Foundation
import Combine

class APIService: ObservableObject {
    static let shared = APIService()
    
    // Base URL - should match your web app server
    private let baseURL = "https://opencare-gpt.vercel.app/api" // Updated to use deployed Vercel backend
    
    private init() {}
    
    // MARK: - Transcription API
    func transcribeAudio(audioData: Data, filename: String) async throws -> TranscriptionResponse {
        print("🌐 API: Starting transcription request...")
        print("🌐 API: Audio data size: \(audioData.count) bytes")
        print("🌐 API: Filename: \(filename)")
        
        guard let url = URL(string: "\(baseURL)/transcribe") else {
            print("❌ API: Invalid URL")
            throw APIError.invalidURL
        }
        
        print("🌐 API: URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add the audio file with correct M4A extension
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🌐 API: Request body size: \(body.count) bytes")
        print("🌐 API: Sending request...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("🌐 API: Response received")
        print("🌐 API: Response data size: \(data.count) bytes")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ API: Invalid response type")
            throw APIError.invalidResponse
        }
        
        print("🌐 API: HTTP status code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ API: Server error with status code: \(httpResponse.statusCode)")
            print("❌ API: Error response: \(errorString)")
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
        let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            print("✅ API: Transcription successful")
            return transcriptionResponse
        } catch {
            print("❌ API: JSON decode error: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Summarization API
    func summarizeTranscript(transcript: String) async throws -> SummarizationResponseAPI {
        print("🔊 Step 2: Summarizing transcript...")
        print("🔊 Transcript to summarize: \(transcript)")
        
        guard let url = URL(string: "\(baseURL)/summarise") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["transcript": transcript]
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
            if httpResponse.statusCode != 200 {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
            let summarizationResponse = try JSONDecoder().decode(SummarizationResponseAPI.self, from: data)
            
            if !summarizationResponse.success {
                throw APIError.summarizationFailed(summarizationResponse.error ?? "Unknown error")
            }
            
            // Enhanced logging matching web app functionality
            print("🔊 Summarization response received: \(summarizationResponse)")
            
            // Log detected medications and actions (matching web app logging)
            if let medications = summarizationResponse.medications {
                print("🔊 AI detected medications: \(medications)")
                print("🔊 Number of medications detected: \(medications.count)")
                
                for (index, med) in medications.enumerated() {
                    print("🔊 Medication \(index + 1): \(med.name)")
                    print("   - Dosage: \(med.dosage)")
                    print("   - Frequency: \(med.frequency)")
                    print("   - Route: \(med.route ?? "Not specified")")
                    print("   - Laterality: \(med.laterality ?? "Not specified")")
                    print("   - Instructions: \(med.fullInstructions ?? "Not specified")")
                }
            }
            
            if let medicationActions = summarizationResponse.medicationActions {
                print("🔊 AI detected medication actions: \(medicationActions)")
                print("🔊 Number of medication actions detected: \(medicationActions.count)")
                
                for (index, action) in medicationActions.enumerated() {
                    print("🔊 Medication Action \(index + 1): \(action.action.rawValue)")
                    print("   - Medication: \(action.medicationName)")
                    print("   - Reason: \(action.reason ?? "Not specified")")
                    print("   - Instructions: \(action.newInstructions ?? "Not specified")")
                }
            }
            
            if let chronicConditions = summarizationResponse.chronicConditions {
                print("🔊 AI detected chronic conditions: \(chronicConditions)")
                print("🔊 Number of chronic conditions detected: \(chronicConditions.count)")
            }
            
            // Log visit summary details
            if let summary = summarizationResponse.summary {
                print("🔊 Visit summary created: \(summary)")
            }
            
            if let specialty = summarizationResponse.specialty {
                print("🔊 Medical specialty detected: \(specialty)")
            }
            
            if let date = summarizationResponse.date {
                print("🔊 Visit date detected: \(date)")
            }
            
            return summarizationResponse
        } catch {
            if let apiError = error as? APIError {
                throw apiError
            }
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Enhanced Medication Extraction Fallback (Matches Web App)
    private func extractMedicationsFromTranscript(_ transcript: String) -> [Medication] {
        var extractedMedications: [Medication] = []
        
        // Enhanced regex patterns matching the web app's medication-scheduler.js
        let medicationPatterns = [
            // Pattern 1: "Vigamox drops 4 times daily", "Pred Forte 1 drop 3 times daily"
            "([A-Za-z0-9\\- ]+)(?: drops?| tablets?| capsules?| ointment| eye drops?| solution| cream)\\s*(?:\\d+\\s*drops?\\s*)?(\\d+)\\s*times?\\s*(?:daily|per\\s*day|a\\s*day)",
            
            // Pattern 2: "Use Vigamox 4x daily for 1 week"
            "([A-Za-z0-9\\- ]+)\\s*(\\d+)x?\\s*(?:times?\\s*)?(?:daily|per\\s*day|a\\s*day)\\s*for\\s*(\\d+)\\s*(?:week|wk)s?",
            
            // Pattern 3: "Apply Vigamox 1 drop 4 times daily for 1 week"
            "([A-Za-z0-9\\- ]+)\\s*(\\d+)\\s*drops?\\s*(\\d+)\\s*times?\\s*daily\\s*for\\s*(\\d+)\\s*(?:week|wk)s?",
            
            // Pattern 4: "Vigamox 4x daily x 1 week"
            "([A-Za-z0-9\\- ]+)\\s*(\\d+)x\\s*daily\\s*x\\s*(\\d+)\\s*(?:week|wk)s?",
            
            // Pattern 5: "Use Vigamox 4 times per day for 7 days"
            "([A-Za-z0-9\\- ]+)\\s*(\\d+)\\s*times?\\s*per\\s*day\\s*for\\s*(\\d+)\\s*days?",
            
            // Pattern 6: Simple medication mentions
            "([A-Za-z0-9\\- ]+)(?: drops?| tablets?| capsules?| ointment| eye drops?| solution| cream)"
        ]
        
        for pattern in medicationPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let matches = regex.matches(in: transcript, options: [], range: NSRange(transcript.startIndex..., in: transcript))
                
                for match in matches {
                    var medicationName = ""
                    var frequency = 1
                    var duration = 7 // Default for eye drops
                    var dosage = 1
                    
                    // Extract medication name (always first group)
                    if let nameRange = Range(match.range(at: 1), in: transcript) {
                        medicationName = String(transcript[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    // Extract frequency (if available)
                    if match.numberOfRanges > 2, let freqRange = Range(match.range(at: 2), in: transcript) {
                        frequency = Int(String(transcript[freqRange])) ?? 1
                    }
                    
                    // Extract duration (if available)
                    if match.numberOfRanges > 3, let durRange = Range(match.range(at: 3), in: transcript) {
                        let durationStr = String(transcript[durRange])
                        if durationStr.contains("week") {
                            duration = (Int(durationStr.replacingOccurrences(of: "week", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1) * 7
                        } else {
                            duration = Int(durationStr) ?? 7
                        }
                    }
                    
                    // Extract dosage (if available)
                    if match.numberOfRanges > 4, let doseRange = Range(match.range(at: 4), in: transcript) {
                        dosage = Int(String(transcript[doseRange])) ?? 1
                    }
                    
                    // Create medication if name is valid
                    if !medicationName.isEmpty && medicationName.count > 2 {
                        let medication = Medication(
                            id: UUID().uuidString,
                            userId: "",
                            name: medicationName,
                            dosage: "\(dosage)",
                            frequency: "\(frequency)",
                            timing: "",
                            route: "ophthalmic",
                            laterality: "",
                            duration: "\(duration)",
                            instructions: nil,
                            fullInstructions: "\(dosage > 1 ? "\(dosage) drops " : "")\(frequency) times daily for \(duration) days",
                            isActive: true,
                            discontinuationReason: nil,
                            createdAt: Date(),
                            updatedAt: Date(),
                            discontinuedDate: nil
                        )
                        
                        // Avoid duplicates
                        if !extractedMedications.contains(where: { $0.name.lowercased() == medicationName.lowercased() }) {
                            extractedMedications.append(medication)
                            print("🔍 [FALLBACK] Extracted medication: \(medicationName) - \(frequency)x daily for \(duration) days")
                        }
                    }
                }
            } catch {
                print("❌ [FALLBACK] Regex error for pattern: \(pattern)")
            }
        }
        
        return extractedMedications
    }

    // MARK: - Medication Verification Logic (Matches Web App)
    private func verifyAndEnhanceMedications(_ medications: [Medication], transcript: String) -> [Medication] {
        var enhancedMedications = medications
        
        // Check for stop/discontinue instructions in transcript
        let stopPatterns = [
            "stop\\s+([A-Za-z0-9\\- ]+)(?: drops?| tablets?| capsules?| ointment| eye drops?| solution| cream)",
            "discontinue\\s+([A-Za-z0-9\\- ]+)(?: drops?| tablets?| capsules?| ointment| eye drops?| solution| cream)",
            "no\\s+longer\\s+use\\s+([A-Za-z0-9\\- ]+)(?: drops?| tablets?| capsules?| ointment| eye drops?| solution| cream)",
            "cease\\s+([A-Za-z0-9\\- ]+)(?: drops?| tablets?| capsules?| ointment| eye drops?| solution| cream)"
        ]
        
        for pattern in stopPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let matches = regex.matches(in: transcript, options: [], range: NSRange(transcript.startIndex..., in: transcript))
                
                for match in matches {
                    if let nameRange = Range(match.range(at: 1), in: transcript) {
                        let medicationName = String(transcript[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Mark medication as discontinued
                        if let index = enhancedMedications.firstIndex(where: { $0.name.lowercased() == medicationName.lowercased() }) {
                            enhancedMedications[index].isActive = false
                            enhancedMedications[index].discontinuationReason = "Discontinued per doctor's instructions"
                            enhancedMedications[index].discontinuedDate = Date()
                            print("🛑 [VERIFICATION] Marked medication as discontinued: \(medicationName)")
                        }
                    }
                }
            } catch {
                print("❌ [VERIFICATION] Regex error for stop pattern: \(pattern)")
            }
        }
        
        return enhancedMedications
    }
    
    // MARK: - Enhanced Summarization with Verification
    func summarizeTranscriptWithVerification(_ transcript: String) async throws -> (VisitSummary, [Medication], [MedicationAction]) {
        print("🔍 [API] Starting enhanced transcript summarization with verification...")
        
        // First, try AI-based summarization
        let summarizationResponse = try await summarizeTranscript(transcript: transcript)
        let summary = summarizationResponse.summary ?? ""
        let medications = summarizationResponse.medications ?? []
        let actions = summarizationResponse.medicationActions ?? []
        
        print("🔍 [API] AI detected \(medications.count) medications and \(actions.count) actions")
        
        // Enhanced fallback: If AI returns no medications, use regex extraction
        var finalMedications = medications
        if medications.isEmpty {
            print("🟡 [API] No medications detected by AI, using enhanced fallback extraction...")
            let fallbackMedications = extractMedicationsFromTranscript(transcript)
            finalMedications = fallbackMedications
            print("🔍 [API] Fallback extracted \(fallbackMedications.count) medications")
        }
        
        // Apply medication verification logic (matches web app)
        finalMedications = verifyAndEnhanceMedications(finalMedications, transcript: transcript)
        
        // Log final results
        print("🔍 [API] Final medication count: \(finalMedications.count)")
        print("🔍 [API] Final action count: \(actions.count)")
        
        for medication in finalMedications {
            print("💊 [API] Final medication: \(medication.name) - \(medication.frequency)x daily - Active: \(medication.isActive)")
        }
        
        let visitSummary = VisitSummary(
            summary: summary,
            tldr: summary,
            specialty: summarizationResponse.specialty ?? "General",
            date: summarizationResponse.date ?? "TODAY",
            medications: summarizationResponse.medications ?? [],
            medicationActions: actions.map { $0.action.rawValue },
            chronicConditions: summarizationResponse.chronicConditions ?? []
        )
        return (visitSummary, finalMedications, actions)
    }
    
    // MARK: - Health Assistant API
    func askHealthAssistant(question: String, context: String? = nil) async throws -> HealthAssistantResponse {
        guard let url = URL(string: "\(baseURL)/assistant") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestBody: [String: Any] = ["question": question]
        if let context = context {
            requestBody["context"] = context
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
            if httpResponse.statusCode != 200 {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
            let assistantResponse = try JSONDecoder().decode(HealthAssistantResponse.self, from: data)
            
            if !assistantResponse.success {
                throw APIError.assistantFailed(assistantResponse.error ?? "Unknown error")
            }
            
            return assistantResponse
        } catch {
            if let apiError = error as? APIError {
                throw apiError
            }
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Test API Connection
    func testConnection() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/test") else {
            throw APIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
            if httpResponse.statusCode != 200 {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
            let testResponse = try JSONDecoder().decode([String: Bool].self, from: data)
            return testResponse["success"] ?? false
        } catch {
            if let apiError = error as? APIError {
                throw apiError
            }
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Combined Visit Processing
    func processVisit(audioData: Data, filename: String) async throws -> VisitSummary {
        // Step 1: Transcribe audio
        let transcriptionResponse = try await transcribeAudio(audioData: audioData, filename: filename)
        
        guard let transcript = transcriptionResponse.transcript else {
            throw APIError.transcriptionFailed("No transcript received")
        }
        
        // Step 2: Summarize transcript
        let (summarizationResponse, medications, actions) = try await summarizeTranscriptWithVerification(transcript)
        
        // Step 3: Convert to VisitSummary
        // Convert MedicationAction objects to strings for VisitSummary
        let medicationActionStrings = actions.map { $0.action.rawValue }
        
        let visitSummary = VisitSummary(
            summary: summarizationResponse.summary ?? "",
            tldr: summarizationResponse.tldr ?? "",
            specialty: summarizationResponse.specialty ?? "General",
            date: summarizationResponse.date ?? "TODAY",
            medications: medications,
            medicationActions: medicationActionStrings,
            chronicConditions: summarizationResponse.chronicConditions ?? []
        )
        
        return visitSummary
    }
}

// MARK: - API Configuration
extension APIService {
    func configureBaseURL(_ url: String) {
        // This allows dynamic configuration of the base URL
        // For example, when deploying to different environments
    }
    
    func getBaseURL() -> String {
        return baseURL
    }
}
