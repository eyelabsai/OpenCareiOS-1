// Services/FirebaseService.swift
import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine

class OpenCareFirebaseService: ObservableObject {
    static let shared = OpenCareFirebaseService()
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    private init() {}
    
    /// Web `setUserProfile` stores comma-separated string; iOS uses `[String]`. Accept both when reading.
    private static func parseChronicConditionsField(_ value: Any?) -> [String] {
        if let arr = value as? [String] { return arr }
        if let str = value as? String, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return str.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return []
    }
    
    // MARK: - Medication / action decoding (shared)
    private func decodeMedication(_ data: [String: Any], documentId: String?) -> Medication {
        let id = documentId ?? (data["id"] as? String)
        var medication = Medication(
            id: id,
            userId: data["userId"] as? String,
            name: data["name"] as? String ?? "",
            dosage: data["dosage"] as? String ?? "",
            frequency: data["frequency"] as? String ?? "",
            timing: data["timing"] as? String,
            route: data["route"] as? String,
            laterality: data["laterality"] as? String,
            duration: data["duration"] as? String,
            instructions: data["instructions"] as? String,
            fullInstructions: data["fullInstructions"] as? String,
            isActive: data["isActive"] as? Bool ?? true,
            discontinuationReason: data["discontinuationReason"] as? String,
            createdAt: nil,
            updatedAt: nil,
            discontinuedDate: nil,
            context: nil,
            lifecycle: nil,
            startDate: nil,
            visitDate: data["visitDate"] as? String
        )
        if let contextString = data["context"] as? String {
            medication.context = MedicationContext(rawValue: contextString)
        }
        if let lifecycleString = data["lifecycle"] as? String {
            medication.lifecycle = MedicationLifecycle(rawValue: lifecycleString)
        }
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            medication.createdAt = createdAtTimestamp.dateValue()
        }
        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            medication.updatedAt = updatedAtTimestamp.dateValue()
        }
        if let discontinuedDateTimestamp = data["discontinuedDate"] as? Timestamp {
            medication.discontinuedDate = discontinuedDateTimestamp.dateValue()
        }
        if let startDate = data["startDate"] as? Timestamp {
            medication.startDate = startDate.dateValue()
        }
        return medication
    }
    
    private func decodeMedicationAction(_ actionData: [String: Any], documentId: String) -> MedicationAction? {
        guard let actionString = actionData["action"] as? String,
              let actionType = MedicationActionType(rawValue: actionString) else {
            return nil
        }
        let medicationName = (actionData["medicationName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var action = MedicationAction(
            id: actionData["id"] as? String,
            visitId: actionData["visitId"] as? String,
            medicationId: actionData["medicationId"] as? String,
            action: actionType,
            medicationName: medicationName,
            genericReference: actionData["genericReference"] as? String,
            reason: actionData["reason"] as? String,
            newInstructions: actionData["newInstructions"] as? String,
            createdAt: nil
        )
        if action.id == nil { action.id = documentId }
        if let createdAtTimestamp = actionData["createdAt"] as? Timestamp {
            action.createdAt = createdAtTimestamp.dateValue()
        }
        return action
    }
    
    /// Medication actions stored nested on a visit document (no Firestore sub-id).
    private func decodeMedicationActionEmbedded(_ actionData: [String: Any]) -> MedicationAction? {
        guard let actionString = actionData["action"] as? String,
              let actionType = MedicationActionType(rawValue: actionString) else {
            return nil
        }
        let medicationName = (actionData["medicationName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var action = MedicationAction(
            id: actionData["id"] as? String,
            visitId: actionData["visitId"] as? String,
            medicationId: actionData["medicationId"] as? String,
            action: actionType,
            medicationName: medicationName,
            genericReference: actionData["genericReference"] as? String,
            reason: actionData["reason"] as? String,
            newInstructions: actionData["newInstructions"] as? String,
            createdAt: nil
        )
        if let createdAtTimestamp = actionData["createdAt"] as? Timestamp {
            action.createdAt = createdAtTimestamp.dateValue()
        } else if let createdAtTimestamp = actionData["createdAt"] as? Date {
            action.createdAt = createdAtTimestamp
        }
        return action
    }
    
    // MARK: - Authentication
    func signIn(email: String, password: String) async throws -> User {
        let result = try await auth.signIn(withEmail: email, password: password)
        return try await getUserData(userId: result.user.uid)
    }
    
    func signUp(email: String, password: String, userData: User) async throws -> User {
        let result = try await auth.createUser(withEmail: email, password: password)
        var newUser = userData
        newUser.id = result.user.uid
        newUser.createdAt = Date()
        newUser.updatedAt = Date()
        
        try await saveUser(newUser)
        return newUser
    }
    
    func signOut() throws {
        try auth.signOut()
    }
    
    // MARK: - Account Management
    func deleteAccount(userId: String) async throws {
        print("Starting account deletion for user: \(userId)")
        
        // First, delete all user-related data from Firestore
        let batch = db.batch()
        
        do {
            // Delete user's visits
            print("Deleting user visits...")
            let visitsSnapshot = try await db.collection("visits")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            for document in visitsSnapshot.documents {
                batch.deleteDocument(document.reference)
            }
            print("Found \(visitsSnapshot.documents.count) visits to delete")
            
            // Delete user's medications
            print("Deleting user medications...")
            let medicationsSnapshot = try await db.collection("medications")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            for document in medicationsSnapshot.documents {
                batch.deleteDocument(document.reference)
            }
            print("Found \(medicationsSnapshot.documents.count) medications to delete")
            
            // Delete user profile
            print("Deleting user profile...")
            batch.deleteDocument(db.collection("users").document(userId))
            
            // Commit the batch
            print("Committing batch deletion...")
            try await batch.commit()
            print("Firestore data deletion completed")
            
        } catch {
            print("Error during Firestore deletion: \(error.localizedDescription)")
            // Don't throw here - we still want to try to delete the auth account
        }
        
        // Finally, delete the Firebase Auth account
        print("Deleting Firebase Auth account...")
        guard let currentUser = auth.currentUser else {
            throw FirebaseError.userNotFound
        }
        
        try await currentUser.delete()
        print("Firebase Auth account deleted successfully")
    }
    
    // MARK: - User Management
    func getUserData(userId: String) async throws -> User {
        print("Fetching user data for userId: \(userId)")
        
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard document.exists else {
            print("User document does not exist for userId: \(userId)")
            throw FirebaseError.userNotFound
        }
        
        guard let data = document.data() else {
            print("User document exists but has no data for userId: \(userId)")
            throw FirebaseError.invalidData
        }
        
        print("Successfully fetched user data for userId: \(userId)")
        
        // Convert Firestore data to User object safely
        var user = User()
        user.id = document.documentID
        user.email = data["email"] as? String ?? ""
        user.firstName = data["firstName"] as? String ?? ""
        user.lastName = data["lastName"] as? String ?? ""
        user.dob = data["dob"] as? String ?? ""
        user.gender = data["gender"] as? String ?? ""
        user.phoneNumber = data["phoneNumber"] as? String ?? ""
        user.street = data["street"] as? String ?? ""
        user.city = data["city"] as? String ?? ""
        user.state = data["state"] as? String ?? ""
        user.zip = data["zip"] as? String ?? ""
        user.insuranceProvider = data["insuranceProvider"] as? String ?? ""
        user.insuranceMemberId = data["insuranceMemberId"] as? String ?? ""
        user.allergies = data["allergies"] as? [String] ?? []
        user.chronicConditions = Self.parseChronicConditionsField(data["chronicConditions"])
        user.heightFeet = String(data["heightFeet"] as? Int ?? 0)
        user.heightInches = String(data["heightInches"] as? Int ?? 0)
        user.weight = String(data["weight"] as? Double ?? 0.0)
        user.emergencyContactName = data["emergencyContactName"] as? String ?? ""
        user.emergencyContactPhone = data["emergencyContactPhone"] as? String ?? ""
        user.primaryPhysician = data["primaryPhysician"] as? String ?? ""
        user.bloodType = data["bloodType"] as? String ?? ""
        
        // Convert Timestamps to Dates
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            user.createdAt = createdAtTimestamp.dateValue()
        }
        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            user.updatedAt = updatedAtTimestamp.dateValue()
        }
        
        return user
    }
    
    func userProfileExists(userId: String) async -> Bool {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            return document.exists && document.data() != nil
        } catch {
            print("Error checking if user profile exists: \(error.localizedDescription)")
            return false
        }
    }
    
    private func saveUser(_ user: User) async throws {
        var dict: [String: Any] = [
            "email": user.email,
            "firstName": user.firstName,
            "lastName": user.lastName,
            "dob": user.dob,
            "gender": user.gender,
            "phoneNumber": user.phoneNumber,
            "street": user.street,
            "city": user.city,
            "state": user.state,
            "zip": user.zip,
            "insuranceProvider": user.insuranceProvider,
            "insuranceMemberId": user.insuranceMemberId,
            "allergies": user.allergies,
            "chronicConditions": user.chronicConditions,
            "heightFeet": Int(user.heightFeet) ?? 0,
            "heightInches": Int(user.heightInches) ?? 0,
            "weight": Double(user.weight) ?? 0.0,
            "emergencyContactName": user.emergencyContactName,
            "emergencyContactPhone": user.emergencyContactPhone,
            "primaryPhysician": user.primaryPhysician,
            "bloodType": user.bloodType
        ]
        
        // Convert Date objects to Firestore Timestamps
        if let createdAt = user.createdAt {
            dict["createdAt"] = Timestamp(date: createdAt)
        }
        if let updatedAt = user.updatedAt {
            dict["updatedAt"] = Timestamp(date: updatedAt)
        }
        
        try await db.collection("users").document(user.id!).setData(dict)
    }
    
    func updateUser(_ user: User) async throws {
        var updatedUser = user
        updatedUser.updatedAt = Date()
        try await saveUser(updatedUser)
    }
    
    // MARK: - Visit Management
    func createVisit(_ visit: Visit, userId: String) async throws {
        let newVisit = visit
        
        // Convert MedicationAction objects to Firestore-compatible dictionaries
        let medicationActionsDict = (newVisit.medicationActions ?? []).map { action in
            var dict: [String: Any] = [
                "id": action.id as Any,
                "visitId": action.visitId as Any,
                "medicationId": action.medicationId as Any,
                "action": action.action.rawValue, // Convert enum to string
                "medicationName": action.medicationName,
                "genericReference": action.genericReference as Any,
                "reason": action.reason as Any,
                "newInstructions": action.newInstructions as Any
            ]
            if let createdAt = action.createdAt {
                dict["createdAt"] = Timestamp(date: createdAt)
            }
            return dict
        }
        // Convert Medication objects to Firestore-compatible dictionaries
        let medicationsDict = (newVisit.medications ?? []).map { med in
        var dict: [String: Any] = [
                "id": med.id as Any,
                "userId": med.userId as Any,
                "name": med.name,
                "dosage": med.dosage,
                "frequency": med.frequency,
                "timing": med.timing as Any,
                "route": med.route as Any,
                "laterality": med.laterality as Any,
                "duration": med.duration as Any,
                "instructions": med.instructions as Any,
                "fullInstructions": med.fullInstructions as Any,
                "isActive": med.isActive as Any,
                "discontinuationReason": med.discontinuationReason as Any,
                // Enhanced fields matching web app
                "context": med.context?.rawValue as Any,
                "lifecycle": med.lifecycle?.rawValue as Any
            ]
            if let createdAt = med.createdAt {
                dict["createdAt"] = Timestamp(date: createdAt)
            }
            if let updatedAt = med.updatedAt {
                dict["updatedAt"] = Timestamp(date: updatedAt)
            }
            if let discontinuedDate = med.discontinuedDate {
                dict["discontinuedDate"] = Timestamp(date: discontinuedDate)
            }
            if let startDate = med.startDate {
                dict["startDate"] = Timestamp(date: startDate)
            }
            if let vd = med.visitDate {
                dict["visitDate"] = vd
            }
            return dict
        }
        // Prepare the visit dictionary (document ID is Firestore-generated; matches web `createVisit`.)
        var visitDict: [String: Any] = [
            "userId": userId,
            "specialty": newVisit.specialty as Any,
            "summary": newVisit.summary as Any,
            "tldr": newVisit.tldr as Any,
            "medications": medicationsDict,
            "medicationActions": medicationActionsDict,
            "date": Timestamp(date: newVisit.date ?? Date()),
            "createdAt": Timestamp(date: newVisit.createdAt ?? Date()),
            "updatedAt": Timestamp(date: newVisit.updatedAt ?? Date())
        ]
        
        if let transcript = newVisit.transcript, !transcript.isEmpty {
            visitDict["transcript"] = transcript
        }
        
        // Add enhanced fields matching web app
        if let setting = newVisit.setting {
            visitDict["setting"] = setting.rawValue
        }
        if let isDischarge = newVisit.isDischarge {
            visitDict["isDischarge"] = isDischarge
        }
        if let startedAt = newVisit.startedAt {
            visitDict["startedAt"] = Timestamp(date: startedAt)
        }
        // Save to Firestore
        _ = try await db.collection("visits").addDocument(data: visitDict)
    }
    
    func getUserVisits(userId: String) async throws -> [Visit] {
        let snapshot: QuerySnapshot
        do {
            snapshot = try await db.collection("visits")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
        } catch {
            snapshot = try await db.collection("visits")
                .whereField("userId", isEqualTo: userId)
                .order(by: "date", descending: true)
                .getDocuments()
        }
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            
            var visit = Visit()
            visit.id = document.documentID
            visit.specialty = data["specialty"] as? String ?? ""
            visit.summary = data["summary"] as? String ?? ""
            visit.tldr = data["tldr"] as? String ?? ""
            visit.transcript = data["transcript"] as? String
            
            if let medicationsData = data["medications"] as? [[String: Any]] {
                visit.medications = medicationsData.map { decodeMedication($0, documentId: nil) }
            } else {
                visit.medications = []
            }
            
            let medicationActionsData = data["medicationActions"] as? [[String: Any]] ?? []
            visit.medicationActions = medicationActionsData.compactMap { decodeMedicationActionEmbedded($0) }
            
            visit.chronicConditions = data["chronicConditions"] as? [String] ?? []
            
            if let dateTimestamp = data["date"] as? Timestamp {
                visit.date = dateTimestamp.dateValue()
            } else if let dateString = data["date"] as? String {
                visit.date = VisitSummaryDate.resolvedDate(from: dateString)
            }
            if let createdAtTimestamp = data["createdAt"] as? Timestamp {
                visit.createdAt = createdAtTimestamp.dateValue()
            }
            if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
                visit.updatedAt = updatedAtTimestamp.dateValue()
            }
            
            if let settingString = data["setting"] as? String {
                visit.setting = VisitSetting(rawValue: settingString)
            }
            visit.isDischarge = data["isDischarge"] as? Bool
            if let startedAtTimestamp = data["startedAt"] as? Timestamp {
                visit.startedAt = startedAtTimestamp.dateValue()
            } else if let startedAtString = data["startedAt"] as? String {
                visit.startedAt = ISO8601DateFormatter().date(from: startedAtString)
            }
            
            return visit
        }
    }
    
    func getVisitById(visitId: String) async throws -> Visit? {
        let document = try await db.collection("visits").document(visitId).getDocument()
        guard let data = document.data() else { return nil }
        
        var visit = Visit()
        visit.id = document.documentID
        visit.specialty = data["specialty"] as? String ?? ""
        visit.summary = data["summary"] as? String ?? ""
        visit.tldr = data["tldr"] as? String ?? ""
        visit.transcript = data["transcript"] as? String
        
        if let medicationsData = data["medications"] as? [[String: Any]] {
            visit.medications = medicationsData.map { decodeMedication($0, documentId: nil) }
        } else {
            visit.medications = []
        }
        
        let medicationActionsData = data["medicationActions"] as? [[String: Any]] ?? []
        visit.medicationActions = medicationActionsData.compactMap { decodeMedicationActionEmbedded($0) }
        
        visit.chronicConditions = data["chronicConditions"] as? [String] ?? []
        
        if let dateTimestamp = data["date"] as? Timestamp {
            visit.date = dateTimestamp.dateValue()
        } else if let dateString = data["date"] as? String {
            visit.date = VisitSummaryDate.resolvedDate(from: dateString)
        }
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            visit.createdAt = createdAtTimestamp.dateValue()
        }
        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            visit.updatedAt = updatedAtTimestamp.dateValue()
        }
        
        if let settingString = data["setting"] as? String {
            visit.setting = VisitSetting(rawValue: settingString)
        }
        visit.isDischarge = data["isDischarge"] as? Bool
        if let startedAtTimestamp = data["startedAt"] as? Timestamp {
            visit.startedAt = startedAtTimestamp.dateValue()
        } else if let startedAtString = data["startedAt"] as? String {
            visit.startedAt = ISO8601DateFormatter().date(from: startedAtString)
        }
        
        return visit
    }
    
    func updateVisit(visitId: String, updates: [String: Any]) async throws {
        var updateData = updates
        updateData["updatedAt"] = Timestamp(date: Date())
        try await db.collection("visits").document(visitId).updateData(updateData)
    }
    
    func deleteVisit(_ visitId: String) async throws {
        try await db.collection("visits").document(visitId).delete()
    }
    
    // MARK: - Medication Management
    func createMedication(_ medication: Medication, userId: String) async throws {
        var newMedication = medication
        newMedication.isActive = true
        newMedication.createdAt = Date()
        newMedication.updatedAt = Date()
        
        var dict: [String: Any] = [
            "userId": userId,
            "name": newMedication.name.lowercased(),
            "dosage": newMedication.dosage,
            "frequency": newMedication.frequency,
            "timing": newMedication.timing as Any,
            "route": newMedication.route as Any,
            "laterality": newMedication.laterality as Any,
            "duration": newMedication.duration as Any,
            "instructions": newMedication.instructions as Any,
            "fullInstructions": newMedication.fullInstructions as Any,
            "isActive": newMedication.isActive ?? true,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]
        
        // Enhanced fields matching web app
        if let context = newMedication.context {
            dict["context"] = context.rawValue
        }
        if let lifecycle = newMedication.lifecycle {
            dict["lifecycle"] = lifecycle.rawValue
        }
        if let startDate = newMedication.startDate {
            dict["startDate"] = Timestamp(date: startDate)
        }
        if let visitDate = newMedication.visitDate, !visitDate.isEmpty {
            dict["visitDate"] = visitDate
        }
        
        try await db.collection("medications").addDocument(data: dict)
    }
    
    func getUserMedications(userId: String) async throws -> [Medication] {
        let snapshot = try await db.collection("medications")
            .whereField("userId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.map { decodeMedication($0.data(), documentId: $0.documentID) }
    }
    
    func getAllUserMedications(userId: String) async throws -> [Medication] {
        let snapshot = try await db.collection("medications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.map { decodeMedication($0.data(), documentId: $0.documentID) }
    }
    
    func checkMedicationExists(userId: String, medicationName: String) async throws -> Bool {
        let snapshot = try await db.collection("medications")
            .whereField("userId", isEqualTo: userId)
            .whereField("name", isEqualTo: medicationName.lowercased())
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
    
    func getMedicationByName(userId: String, medicationName: String) async throws -> Medication? {
        let snapshot = try await db.collection("medications")
            .whereField("userId", isEqualTo: userId)
            .whereField("name", isEqualTo: medicationName.lowercased())
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        
        guard let document = snapshot.documents.first else { return nil }
        
        return decodeMedication(document.data(), documentId: document.documentID)
    }
    
    func updateMedication(medicationId: String, updates: [String: Any]) async throws {
        var updateData = updates
        updateData["updatedAt"] = Timestamp(date: Date())
        try await db.collection("medications").document(medicationId).updateData(updateData)
    }
    
    func discontinueMedication(medicationId: String, reason: String? = nil) async throws {
        var updateData: [String: Any] = [
            "isActive": false,
            "discontinuedDate": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let reason = reason {
            updateData["discontinuationReason"] = reason
        }
        
        try await db.collection("medications").document(medicationId).updateData(updateData)
    }
    
    func deleteMedication(_ medicationId: String) async throws {
        try await db.collection("medications").document(medicationId).delete()
    }
    
    // MARK: - Visit-Medication Relationship Services
    func recordMedicationAction(_ action: MedicationAction) async throws {
        var actionData: [String: Any] = [
            "visitId": action.visitId,
            "medicationId": action.medicationId ?? "",
            "action": action.action.rawValue,
            "medicationName": action.medicationName,
            "reason": action.reason ?? "",
            "newInstructions": action.newInstructions ?? "",
            "createdAt": Timestamp(date: Date())
        ]
        
        if let genericReference = action.genericReference {
            actionData["genericReference"] = genericReference
        }
        
        try await db.collection("visit_medications").addDocument(data: actionData)
    }
    
    func getMedicationHistory(medicationId: String) async throws -> [MedicationAction] {
        let snapshot = try await db.collection("visit_medications")
            .whereField("medicationId", isEqualTo: medicationId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            decodeMedicationAction(document.data(), documentId: document.documentID)
        }
    }
    
    func getVisitMedicationActions(visitId: String) async throws -> [MedicationAction] {
        let snapshot = try await db.collection("visit_medications")
            .whereField("visitId", isEqualTo: visitId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            decodeMedicationAction(document.data(), documentId: document.documentID)
        }
    }
    
    // MARK: - Public Firestore Accessor
    public func getFirestore() -> Firestore {
        return db
    }
    
    // MARK: - JSON Decoder
    public func getJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - Firebase Errors
enum FirebaseError: Error, LocalizedError {
    case userNotFound
    case invalidData
    case networkError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .invalidData:
            return "Invalid data format"
        case .networkError:
            return "Network error occurred"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}
