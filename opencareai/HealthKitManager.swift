//
//  HealthKitManager.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/21/25.
//

import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()

   
    private var readTypes: Set<HKObjectType> {
            var types: Set<HKObjectType> = [
                HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
                HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
                HKObjectType.quantityType(forIdentifier: .height)!,
                HKObjectType.quantityType(forIdentifier: .bodyMass)!
            ]
            
            // Add clinical medication records
            types.insert(HKClinicalType(.medicationRecord))
            
            return types
        }

    private var writeTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        
        // Add fallback to mindful session workaround for iOS 16+
        if #available(iOS 16.0, *) {
            types.insert(HKObjectType.categoryType(forIdentifier: .mindfulSession)!)
        }
        
        return types
    }


    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        // Check if HealthKit is available on the device
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device.")
            completion(false)
            return
        }

        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            if let error = error {
                print("HealthKit Authorization Error: \(error.localizedDescription)")
            }
            completion(success)
        }
    }

    
    func fetchCharacteristics() throws -> (dateOfBirth: Date?, biologicalSex: HKBiologicalSexObject?) {
            let dateOfBirth = try healthStore.dateOfBirthComponents().date
            let biologicalSex = try healthStore.biologicalSex()
            return (dateOfBirth, biologicalSex)
        }

     
        func fetchMostRecentHeight(completion: @escaping (Double?) -> Void) {
            guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else { completion(nil); return }
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: heightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                let heightInInches = sample.quantity.doubleValue(for: .inch())
                DispatchQueue.main.async { completion(heightInInches) }
            }
            healthStore.execute(query)
        }
        
  
        func fetchMostRecentWeight(completion: @escaping (Double?) -> Void) {
            guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { completion(nil); return }
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                let weightInPounds = sample.quantity.doubleValue(for: .pound())
                DispatchQueue.main.async { completion(weightInPounds) }
            }
            healthStore.execute(query)
        }

    // MARK: - Medication Syncing
    
    func fetchAppleHealthMedications(completion: @escaping ([AppleHealthMedication]) -> Void) {
        print("🔄 Fetching medications from Apple Health")
        
        // First try to fetch clinical medication records
        fetchClinicalMedicationRecords { clinicalMedications in
            // Then try to fetch user-entered medications (if iOS 15+ APIs are available)
            self.fetchUserAnnotatedMedications { userMedications in
                let allMedications = clinicalMedications + userMedications
                print("✅ Fetched \(allMedications.count) medications from Apple Health (\(clinicalMedications.count) clinical, \(userMedications.count) user-entered)")
                completion(allMedications)
            }
        }
    }
    
    func fetchClinicalMedicationRecords(completion: @escaping ([AppleHealthMedication]) -> Void) {
        let medicationType = HKClinicalType(.medicationRecord)
        
        // Create predicate for medication statements
        let predicate = HKQuery.predicateForClinicalRecords(withFHIRResourceType: .medicationStatement)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: medicationType,
            predicate: predicate,
            limit: 100,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                print("❌ Error fetching clinical medication records: \(error.localizedDescription)")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            let medications = samples?.compactMap { sample -> AppleHealthMedication? in
                guard let clinicalRecord = sample as? HKClinicalRecord else { return nil }
                
                // Parse FHIR data for medication information
                if let fhirResource = clinicalRecord.fhirResource,
                   let json = try? JSONSerialization.jsonObject(with: fhirResource.data) as? [String: Any] {
                    
                    // Extract medication name from FHIR resource
                    var medicationName: String?
                    var dosage: String?
                    
                    // Try to extract medication name from various FHIR fields
                    if let medicationCodeableConcept = json["medicationCodeableConcept"] as? [String: Any],
                       let coding = medicationCodeableConcept["coding"] as? [[String: Any]],
                       let firstCoding = coding.first,
                       let display = firstCoding["display"] as? String {
                        medicationName = display
                    } else if let medicationReference = json["medicationReference"] as? [String: Any],
                              let display = medicationReference["display"] as? String {
                        medicationName = display
                    }
                    
                    // Try to extract dosage information
                    if let dosageInstruction = json["dosageInstruction"] as? [[String: Any]],
                       let firstDosage = dosageInstruction.first,
                       let text = firstDosage["text"] as? String {
                        dosage = text
                    }
                    
                    if let name = medicationName {
                        return AppleHealthMedication(
                            displayName: name,
                            brandName: nil,
                            genericName: name,
                            medicationIdentifier: clinicalRecord.fhirResource?.identifier,
                            dosageFormCode: nil,
                            strengthQuantity: nil,
                            dosageString: dosage ?? "As prescribed"
                        )
                    }
                }
                
                return nil
            } ?? []
            
            DispatchQueue.main.async {
                completion(medications)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchUserAnnotatedMedications(completion: @escaping ([AppleHealthMedication]) -> Void) {
        // Unfortunately, user-entered medications in Apple Health are NOT accessible 
        // via HealthKit APIs in the current iOS versions.
        // 
        // According to Apple Developer Forums, medications manually entered by users 
        // in the Health app are not available through HealthKit APIs.
        // 
        // Only clinical medication records (from healthcare providers) can be accessed.
        
        print("ℹ️ User-entered medications are not accessible via HealthKit APIs")
        print("ℹ️ Only clinical medication records from healthcare providers can be read")
        
        completion([])
    }
    
    func fetchMedicationDoses(completion: @escaping ([HKCategorySample]) -> Void) {
        if #available(iOS 18.0, *) {
            // For iOS 18+, we'll focus on reading medications directly
            // This method is kept for backward compatibility
            completion([])
            return
        }
        
        guard #available(iOS 16.0, *) else {
            print("Medication tracking requires iOS 16.0 or later")
            completion([])
            return
        }
        
        guard let medicationType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            print("Mindful session type not available")
            completion([])
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: medicationType, predicate: nil, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let medicationSamples = samples as? [HKCategorySample] ?? []
            
            DispatchQueue.main.async {
                completion(medicationSamples)
            }
        }
        healthStore.execute(query)
    }
    
    func writeMedicationDose(medicationName: String, dosage: String, dateTaken: Date, completion: @escaping (Bool, Error?) -> Void) {
        guard #available(iOS 16.0, *) else {
            let error = NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Medication tracking requires iOS 16.0 or later"])
            completion(false, error)
            return
        }
        
        guard let medicationType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            let error = NSError(domain: "HealthKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mindful session type not available"])
            completion(false, error)
            return
        }
        
        let metadata: [String: Any] = [
            "medicationDosage": dosage,
            "medicationName": medicationName,
            "isMedicationDose": true
        ]
        
        // For mindful session, use value 0 (not applicable)
        let sample = HKCategorySample(
            type: medicationType,
            value: 0, // HKCategoryValueMindfulSession.notApplicable
            start: dateTaken,
            end: dateTaken,
            metadata: metadata
        )
        
        print("📝 Writing medication to HealthKit:")
        print("   Medication: \(medicationName)")
        print("   Dosage: \(dosage)")
        print("   Date: \(dateTaken)")
        
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully wrote \(medicationName) to Apple Health (as Mindful Session)")
                    print("   🔍 To see in Health app:")
                    print("      1. Open Health app")
                    print("      2. Tap 'Browse' tab")
                    print("      3. Tap 'Mindfulness'")
                    print("      4. Look for entries with medication metadata")
                } else {
                    print("❌ Failed to write \(medicationName): \(error?.localizedDescription ?? "Unknown error")")
                }
                completion(success, error)
            }
        }
    }
    
    func syncMedicationsFromHealthKit(completion: @escaping ([MedicationDoseRecord]) -> Void) {
        // Use the unified medication fetching approach
        fetchAppleHealthMedications { appleHealthMedications in
            let records = appleHealthMedications.map { medication in
                MedicationDoseRecord(
                    name: medication.preferredName,
                    dosage: medication.effectiveDosageString,
                    dateTaken: Date() // Since we don't have dose events, use current date as placeholder
                )
            }
            completion(records)
        }
    }
    
    // MARK: - Modern Sync
    
    func syncAppleHealthMedicationsToApp(
        existingMedications: [Medication],
        completion: @escaping (AppleHealthSyncResult) -> Void
    ) {
        fetchAppleHealthMedications { appleHealthMedications in
            var newMedications: [Medication] = []
            var matchedCount = 0
            
            for appleHealthMed in appleHealthMedications {
                let normalizedName = self.normalizedMedicationName(appleHealthMed.preferredName)
                
                // Check if medication already exists in app
                let existsInApp = existingMedications.contains { appMed in
                    self.normalizedMedicationName(appMed.name) == normalizedName
                }
                
                if existsInApp {
                    matchedCount += 1
                } else {
                    // Create new medication from Apple Health data
                    let newMedication = Medication(
                        id: nil,
                        userId: nil,
                        name: appleHealthMed.preferredName,
                        dosage: appleHealthMed.effectiveDosageString,
                        frequency: "As prescribed",
                        timing: nil,
                        route: nil,
                        laterality: nil,
                        duration: nil,
                        instructions: nil,
                        fullInstructions: "Synced from Apple Health",
                        isActive: true,
                        discontinuationReason: nil,
                        createdAt: nil,
                        updatedAt: nil,
                        discontinuedDate: nil
                    )
                    newMedications.append(newMedication)
                }
            }
            
            let result = AppleHealthSyncResult(
                totalAppleHealthMedications: appleHealthMedications.count,
                newMedicationsToAdd: newMedications,
                matchedMedications: matchedCount
            )
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // MARK: - Two-Way Sync & Auto-Matching
    
    func performTwoWayMedicationSync(
        appMedications: [Medication],
        completion: @escaping (MedicationSyncResult) -> Void
    ) {
        syncMedicationsFromHealthKit { healthKitRecords in
            let syncResult = self.reconcileMedications(
                appMedications: appMedications,
                healthKitRecords: healthKitRecords
            )
            
            // Write app medications to HealthKit that aren't already there
            self.writeAppMedicationsToHealthKit(syncResult.medicationsToWriteToHealthKit) { success in
                var finalResult = syncResult
                finalResult.healthKitWriteSuccess = success
                completion(finalResult)
            }
        }
    }
    
    private func reconcileMedications(
        appMedications: [Medication],
        healthKitRecords: [MedicationDoseRecord]
    ) -> MedicationSyncResult {
        var matchedMedications: [MedicationMatch] = []
        var unmatchedHealthKitRecords: [MedicationDoseRecord] = []
        var medicationsToWriteToHealthKit: [Medication] = []
        
        // Group HealthKit records by medication name
        let healthKitMedicationGroups = Dictionary(grouping: healthKitRecords) { record in
            normalizedMedicationName(record.name)
        }
        
        // Find matches and unmatched items
        for appMedication in appMedications.filter({ $0.isCurrentlyActive }) {
            let normalizedAppName = normalizedMedicationName(appMedication.name)
            
            if let healthKitGroup = healthKitMedicationGroups[normalizedAppName] {
                // Found match - check if dosages are compatible
                let compatibleRecords = healthKitGroup.filter { record in
                    areDosagesCompatible(appDosage: appMedication.dosage, healthKitDosage: record.dosage)
                }
                
                matchedMedications.append(MedicationMatch(
                    appMedication: appMedication,
                    healthKitRecords: compatibleRecords,
                    matchType: compatibleRecords.isEmpty ? .nameOnly : .nameAndDosage
                ))
            } else {
                // App medication not found in HealthKit - write it
                medicationsToWriteToHealthKit.append(appMedication)
            }
        }
        
        // Find unmatched HealthKit records
        let matchedHealthKitNames = Set(matchedMedications.flatMap { match in
            match.healthKitRecords.map { normalizedMedicationName($0.name) }
        })
        
        unmatchedHealthKitRecords = healthKitRecords.filter { record in
            !matchedHealthKitNames.contains(normalizedMedicationName(record.name))
        }
        
        return MedicationSyncResult(
            matchedMedications: matchedMedications,
            unmatchedHealthKitRecords: unmatchedHealthKitRecords,
            medicationsToWriteToHealthKit: medicationsToWriteToHealthKit,
            healthKitWriteSuccess: false
        )
    }
    
    private func normalizedMedicationName(_ name: String) -> String {
        return name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
    }
    
    private func areDosagesCompatible(appDosage: String, healthKitDosage: String) -> Bool {
        // Extract numeric values and units for comparison
        let appNumeric = extractDosageComponents(appDosage)
        let healthKitNumeric = extractDosageComponents(healthKitDosage)
        
        // Consider compatible if within 20% or exact match
        if let appValue = appNumeric.value, let healthKitValue = healthKitNumeric.value {
            let tolerance = appValue * 0.2
            return abs(appValue - healthKitValue) <= tolerance && appNumeric.unit == healthKitNumeric.unit
        }
        
        // Fallback to string comparison
        return normalizedMedicationName(appDosage) == normalizedMedicationName(healthKitDosage)
    }
    
    private func extractDosageComponents(_ dosage: String) -> (value: Double?, unit: String?) {
        let pattern = #"(\d+(?:\.\d+)?)\s*([a-zA-Z]+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(dosage.startIndex..<dosage.endIndex, in: dosage)
        
        if let match = regex?.firstMatch(in: dosage, range: range) {
            let valueRange = Range(match.range(at: 1), in: dosage)
            let unitRange = Range(match.range(at: 2), in: dosage)
            
            if let valueRange = valueRange, let unitRange = unitRange {
                let value = Double(String(dosage[valueRange]))
                let unit = String(dosage[unitRange]).lowercased()
                return (value, unit)
            }
        }
        
        return (nil, nil)
    }
    
    private func writeAppMedicationsToHealthKit(
        _ medications: [Medication],
        completion: @escaping (Bool) -> Void
    ) {
        guard !medications.isEmpty else {
            completion(true)
            return
        }
        
        let group = DispatchGroup()
        var allSuccessful = true
        
        for medication in medications {
            group.enter()
            
            // Write a sample dose for today to represent the medication
            writeMedicationDose(
                medicationName: medication.name,
                dosage: medication.dosage,
                dateTaken: Date()
            ) { success, error in
                if !success {
                    allSuccessful = false
                    print("Failed to write \(medication.name) to HealthKit: \(error?.localizedDescription ?? "Unknown error")")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(allSuccessful)
        }
    }
    
    // MARK: - Automatic Sync When Medication Taken
    
    func recordMedicationTaken(_ medication: Medication, dateTaken: Date = Date()) {
        guard HKHealthStore.isHealthDataAvailable() else { 
            print("HealthKit is not available on this device")
            return 
        }
        
        guard #available(iOS 16.0, *) else {
            print("Medication tracking requires iOS 16.0 or later")
            return
        }
        
        guard let medicationType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            print("Mindful session type not available")
            return
        }
        
        let authStatus = healthStore.authorizationStatus(for: medicationType)
        guard authStatus == .sharingAuthorized else { 
            print("HealthKit not authorized for medication tracking")
            return 
        }
        
        // Write the dose to HealthKit
        writeMedicationDose(
            medicationName: medication.name,
            dosage: medication.dosage,
            dateTaken: dateTaken
        ) { success, error in
            if success {
                print("✅ Recorded \(medication.name) dose in Apple Health (as Mindful Session)")
            } else {
                print("❌ Failed to record \(medication.name) in Apple Health: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
        
}

// MARK: - Helper Models
struct MedicationDoseRecord {
    let name: String
    let dosage: String
    let dateTaken: Date
}

struct AppleHealthMedication {
    let displayName: String
    let brandName: String?
    let genericName: String?
    let medicationIdentifier: String?
    let dosageFormCode: String?
    let strengthQuantity: HKQuantity?
    let dosageString: String? // Add explicit dosage string for compatibility
    
    var preferredName: String {
        return brandName ?? genericName ?? displayName
    }
    
    var effectiveDosageString: String {
        if let dosageString = dosageString {
            return dosageString
        }
        if let quantity = strengthQuantity {
            return quantity.description
        }
        return "Unknown dosage"
    }
    
    // Convenience initializer for legacy support
    init(displayName: String, brandName: String?, genericName: String?, medicationIdentifier: String?, dosageFormCode: String?, strengthQuantity: HKQuantity?, dosageString: String? = nil) {
        self.displayName = displayName
        self.brandName = brandName
        self.genericName = genericName
        self.medicationIdentifier = medicationIdentifier
        self.dosageFormCode = dosageFormCode
        self.strengthQuantity = strengthQuantity
        self.dosageString = dosageString
    }
}

struct MedicationMatch {
    let appMedication: Medication
    let healthKitRecords: [MedicationDoseRecord]
    let matchType: MatchType
    
    enum MatchType {
        case nameAndDosage
        case nameOnly
    }
}

struct MedicationSyncResult {
    let matchedMedications: [MedicationMatch]
    let unmatchedHealthKitRecords: [MedicationDoseRecord]
    let medicationsToWriteToHealthKit: [Medication]
    var healthKitWriteSuccess: Bool
    
    var summary: String {
        let matched = matchedMedications.count
        let unmatched = unmatchedHealthKitRecords.count
        let written = medicationsToWriteToHealthKit.count
        
        return "Matched: \(matched), New from HealthKit: \(unmatched), Written to HealthKit: \(written)"
    }
}

struct AppleHealthSyncResult {
    let totalAppleHealthMedications: Int
    let newMedicationsToAdd: [Medication]
    let matchedMedications: Int
    
    var summary: String {
        return "Found \(totalAppleHealthMedications) medications in Apple Health. \(newMedicationsToAdd.count) new, \(matchedMedications) already in app."
    }
}
