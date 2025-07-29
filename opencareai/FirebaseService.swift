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
    
    // MARK: - User Management
    func getUserData(userId: String) async throws -> User {
        let document = try await db.collection("users").document(userId).getDocument()
        guard let data = document.data() else {
            throw FirebaseError.userNotFound
        }
        
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
        user.chronicConditions = data["chronicConditions"] as? [String] ?? []
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
        var newVisit = visit
        newVisit.id = UUID().uuidString
        
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
                dict["createdAt"] = createdAt
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
                "discontinuationReason": med.discontinuationReason as Any
            ]
            if let createdAt = med.createdAt {
                dict["createdAt"] = createdAt
            }
            if let updatedAt = med.updatedAt {
                dict["updatedAt"] = updatedAt
            }
            if let discontinuedDate = med.discontinuedDate {
                dict["discontinuedDate"] = discontinuedDate
            }
            return dict
        }
        // Prepare the visit dictionary
        let visitDict: [String: Any] = [
            "id": newVisit.id as Any,
            "userId": userId,
            "specialty": newVisit.specialty,
            "summary": newVisit.summary,
            "tldr": newVisit.tldr,
            "medications": medicationsDict,
            "medicationActions": medicationActionsDict,
            "date": newVisit.date ?? Date(),
            "createdAt": newVisit.createdAt ?? Date(),
            "updatedAt": newVisit.updatedAt ?? Date()
        ]
        // Save to Firestore
        _ = try await db.collection("visits").addDocument(data: visitDict)
    }
    
    func getUserVisits(userId: String) async throws -> [Visit] {
        let snapshot = try await db.collection("visits")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            
            var visit = Visit()
            visit.id = document.documentID
            visit.specialty = data["specialty"] as? String ?? ""
            visit.summary = data["summary"] as? String ?? ""
            visit.tldr = data["tldr"] as? String ?? ""
            // Fix: Decode medications from array of dictionaries
            if let medicationsData = data["medications"] as? [[String: Any]] {
                let medications = medicationsData.compactMap { medData -> Medication? in
                    Medication(
                        id: medData["id"] as? String,
                        userId: medData["userId"] as? String,
                        name: medData["name"] as? String ?? "",
                        dosage: medData["dosage"] as? String ?? "",
                        frequency: medData["frequency"] as? String ?? "",
                        timing: medData["timing"] as? String,
                        route: medData["route"] as? String,
                        laterality: medData["laterality"] as? String,
                        duration: medData["duration"] as? String,
                        instructions: medData["instructions"] as? String,
                        fullInstructions: medData["fullInstructions"] as? String,
                        isActive: medData["isActive"] as? Bool,
                        discontinuationReason: medData["discontinuationReason"] as? String,
                        createdAt: (medData["createdAt"] as? Timestamp)?.dateValue(),
                        updatedAt: (medData["updatedAt"] as? Timestamp)?.dateValue(),
                        discontinuedDate: (medData["discontinuedDate"] as? Timestamp)?.dateValue()
                    )
                }
                visit.medications = medications
            } else {
                visit.medications = []
            }
            
            // Reconstruct MedicationAction objects from Firestore data
            let medicationActionsData = data["medicationActions"] as? [[String: Any]] ?? []
            let medicationActions = medicationActionsData.compactMap { actionData -> MedicationAction? in
                guard let actionString = actionData["action"] as? String,
                      let actionType = MedicationActionType(rawValue: actionString),
                      let medicationName = actionData["medicationName"] as? String else {
                    return nil
                }
                
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
                
                // Convert Timestamp to Date
                if let createdAtTimestamp = actionData["createdAt"] as? Timestamp {
                    action.createdAt = createdAtTimestamp.dateValue()
                }
                
                return action
            }
            visit.medicationActions = medicationActions
            
            visit.chronicConditions = data["chronicConditions"] as? [String] ?? []
            
            // Convert Timestamps to Dates
            if let dateTimestamp = data["date"] as? Timestamp {
                visit.date = dateTimestamp.dateValue()
            }
            if let createdAtTimestamp = data["createdAt"] as? Timestamp {
                visit.createdAt = createdAtTimestamp.dateValue()
            }
            if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
                visit.updatedAt = updatedAtTimestamp.dateValue()
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
        // Fix: Decode medications from array of dictionaries
        if let medicationsData = data["medications"] as? [[String: Any]] {
            let medications = medicationsData.compactMap { medData -> Medication? in
                Medication(
                    id: medData["id"] as? String,
                    userId: medData["userId"] as? String,
                    name: medData["name"] as? String ?? "",
                    dosage: medData["dosage"] as? String ?? "",
                    frequency: medData["frequency"] as? String ?? "",
                    timing: medData["timing"] as? String,
                    route: medData["route"] as? String,
                    laterality: medData["laterality"] as? String,
                    duration: medData["duration"] as? String,
                    instructions: medData["instructions"] as? String,
                    fullInstructions: medData["fullInstructions"] as? String,
                    isActive: medData["isActive"] as? Bool,
                    discontinuationReason: medData["discontinuationReason"] as? String,
                    createdAt: (medData["createdAt"] as? Timestamp)?.dateValue(),
                    updatedAt: (medData["updatedAt"] as? Timestamp)?.dateValue(),
                    discontinuedDate: (medData["discontinuedDate"] as? Timestamp)?.dateValue()
                )
            }
            visit.medications = medications
        } else {
            visit.medications = []
        }
        
        // Reconstruct MedicationAction objects from Firestore data
        let medicationActionsData = data["medicationActions"] as? [[String: Any]] ?? []
        let medicationActions = medicationActionsData.compactMap { actionData -> MedicationAction? in
            guard let actionString = actionData["action"] as? String,
                  let actionType = MedicationActionType(rawValue: actionString),
                  let medicationName = actionData["medicationName"] as? String else {
                return nil
            }
            
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
            
            // Convert Timestamp to Date
            if let createdAtTimestamp = actionData["createdAt"] as? Timestamp {
                action.createdAt = createdAtTimestamp.dateValue()
            }
            
            return action
        }
        visit.medicationActions = medicationActions
        
        visit.chronicConditions = data["chronicConditions"] as? [String] ?? []
        
        // Convert Timestamps to Dates
        if let dateTimestamp = data["date"] as? Timestamp {
            visit.date = dateTimestamp.dateValue()
        }
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            visit.createdAt = createdAtTimestamp.dateValue()
        }
        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            visit.updatedAt = updatedAtTimestamp.dateValue()
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
        newMedication.id = UUID().uuidString
        newMedication.isActive = true
        newMedication.createdAt = Date()
        newMedication.updatedAt = Date()
        
        let dict: [String: Any] = [
            "id": newMedication.id ?? "",
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
        
        try await db.collection("medications").addDocument(data: dict)
    }
    
    func getUserMedications(userId: String) async throws -> [Medication] {
        let snapshot = try await db.collection("medications")
            .whereField("userId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            
            var medication = Medication(
                id: document.documentID,
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
                discontinuedDate: nil
            )
            
            // Convert Timestamps to Dates
            if let createdAtTimestamp = data["createdAt"] as? Timestamp {
                medication.createdAt = createdAtTimestamp.dateValue()
            }
            if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
                medication.updatedAt = updatedAtTimestamp.dateValue()
            }
            if let discontinuedDateTimestamp = data["discontinuedDate"] as? Timestamp {
                medication.discontinuedDate = discontinuedDateTimestamp.dateValue()
            }
            
            return medication
        }
    }
    
    func getAllUserMedications(userId: String) async throws -> [Medication] {
        let snapshot = try await db.collection("medications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            
            var medication = Medication(
                id: document.documentID,
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
                discontinuedDate: nil
            )
            
            // Convert Timestamps to Dates
            if let createdAtTimestamp = data["createdAt"] as? Timestamp {
                medication.createdAt = createdAtTimestamp.dateValue()
            }
            if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
                medication.updatedAt = updatedAtTimestamp.dateValue()
            }
            if let discontinuedDateTimestamp = data["discontinuedDate"] as? Timestamp {
                medication.discontinuedDate = discontinuedDateTimestamp.dateValue()
            }
            
            return medication
        }
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
        
        let data = document.data()
        
        var medication = Medication(
            id: document.documentID,
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
            discontinuedDate: nil
        )
        
        // Convert Timestamps to Dates
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            medication.createdAt = createdAtTimestamp.dateValue()
        }
        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            medication.updatedAt = updatedAtTimestamp.dateValue()
        }
        
        return medication
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
            let data = document.data()
            
            var action = MedicationAction(
                id: document.documentID,
                visitId: data["visitId"] as? String ?? "",
                medicationId: data["medicationId"] as? String,
                action: MedicationActionType(rawValue: data["action"] as? String ?? "continue") ?? .continued,
                medicationName: data["medicationName"] as? String ?? "",
                genericReference: data["genericReference"] as? String,
                reason: data["reason"] as? String,
                newInstructions: data["newInstructions"] as? String,
                createdAt: nil
            )
            
            // Convert Timestamps to Dates
            if let createdAtTimestamp = data["createdAt"] as? Timestamp {
                action.createdAt = createdAtTimestamp.dateValue()
            }
            
            return action
        }
    }
    
    func getVisitMedicationActions(visitId: String) async throws -> [MedicationAction] {
        let snapshot = try await db.collection("visit_medications")
            .whereField("visitId", isEqualTo: visitId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            let data = document.data()
            
            var action = MedicationAction(
                id: document.documentID,
                visitId: data["visitId"] as? String ?? "",
                medicationId: data["medicationId"] as? String,
                action: MedicationActionType(rawValue: data["action"] as? String ?? "continue") ?? .continued,
                medicationName: data["medicationName"] as? String ?? "",
                genericReference: data["genericReference"] as? String,
                reason: data["reason"] as? String,
                newInstructions: data["newInstructions"] as? String,
                createdAt: nil
            )
            
            // Convert Timestamps to Dates
            if let createdAtTimestamp = data["createdAt"] as? Timestamp {
                action.createdAt = createdAtTimestamp.dateValue()
    }
    
            return action
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
