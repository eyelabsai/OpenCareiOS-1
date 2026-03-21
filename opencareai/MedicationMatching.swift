// MedicationMatching.swift — ports name matching from `/Users/gurpalvirdi/OpenCare/public/new-visit.html` (stop/modify resolution).

import Foundation

enum MedicationNameMatcher {
    private static let synonymGroups: [[String]] = [
        ["pred", "prednisolone", "pred forte", "prednisolone acetate"],
        ["vigamox", "moxifloxacin"]
    ]
    
    static func normalizeMedName(_ name: String) -> String {
        let lowered = name.lowercased()
        let alphanumeric = lowered.filter { $0.isLetter || $0.isNumber }
        let stripped = ["eyedrops", "tablets", "capsules", "solution", "ointment", "drops", "mg", "ml"].reduce(alphanumeric) { partial, suffix in
            partial.replacingOccurrences(of: suffix, with: "")
        }
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func isSubstringMatch(_ a: String, _ b: String) -> Bool {
        let na = normalizeMedName(a)
        let nb = normalizeMedName(b)
        return na.contains(nb) || nb.contains(na)
    }
    
    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let an = a.count
        let bn = b.count
        if an == 0 { return bn }
        if bn == 0 { return an }
        let ac = Array(a)
        let bc = Array(b)
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: an + 1), count: bn + 1)
        for i in 0...bn { matrix[i][0] = i }
        for j in 0...an { matrix[0][j] = j }
        for i in 1...bn {
            for j in 1...an {
                if bc[i - 1] == ac[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(matrix[i - 1][j - 1] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j] + 1)
                }
            }
        }
        return matrix[bn][an]
    }
    
    private static func isFuzzyMatch(_ a: String, _ b: String, threshold: Int = 2) -> Bool {
        levenshtein(normalizeMedName(a), normalizeMedName(b)) <= threshold
    }
    
    private static func areSynonyms(_ a: String, _ b: String) -> Bool {
        let na = normalizeMedName(a)
        let nb = normalizeMedName(b)
        for group in synonymGroups {
            let normalized = group.map { normalizeMedName($0) }
            if normalized.contains(na), normalized.contains(nb) { return true }
        }
        return false
    }
    
    static func isMedMatch(_ newMed: String, _ existingMed: String) -> Bool {
        isSubstringMatch(newMed, existingMed) || isFuzzyMatch(newMed, existingMed) || areSynonyms(newMed, existingMed)
    }
    
    /// Mirrors web `findActiveMedicationMatch`: exact name, fuzzy match on active list, then generic reference.
    static func findActiveMedicationMatch(
        medicationName: String?,
        genericReference: String?,
        activeMedications: [Medication]
    ) -> Medication? {
        if let name = medicationName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            if let exact = activeMedications.first(where: { $0.name.lowercased() == name.lowercased() }) {
                return exact
            }
            if let fuzzy = activeMedications.first(where: { isMedMatch(name, $0.name) }) {
                return fuzzy
            }
        }
        if let g = genericReference?.trimmingCharacters(in: .whitespacesAndNewlines), !g.isEmpty {
            let gl = g.lowercased()
            return activeMedications.first { med in
                med.name.lowercased().contains(gl)
                    || (med.fullInstructions?.lowercased().contains(gl) ?? false)
            }
        }
        return nil
    }
    
    /// Mirrors web `displayMedicationVerification` preprocessing: meds covered by an AI stop/discontinue action are omitted from the table; stop phrases in `fullInstructions` become synthetic stop actions.
    static func medicationsAndActionsForNewVisitVerification(
        medications: [Medication],
        medicationActions: [MedicationAction]
    ) -> ([Medication], [MedicationAction]) {
        let stopPhrases = [
            "stop using", "discontinue", "stop taking", "cease", "end", "no longer need",
            "can stop", "should stop", "stop", "discontinue the use of"
        ]
        var derivedStops: [MedicationAction] = []
        var filteredMeds: [Medication] = []
        for med in medications {
            let name = med.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { continue }
            let hasAIStop = medicationActions.contains { act in
                act.action.isStopLike
                    && !act.medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && isMedMatch(name, act.medicationName)
            }
            if hasAIStop {
                continue
            }
            let instructions = (med.fullInstructions ?? "").lowercased()
            if stopPhrases.contains(where: { instructions.contains($0) }) {
                derivedStops.append(MedicationAction(
                    id: nil,
                    visitId: nil,
                    medicationId: nil,
                    action: .stop,
                    medicationName: med.name,
                    genericReference: nil,
                    reason: med.fullInstructions ?? "Discontinued per doctor instructions",
                    newInstructions: nil,
                    createdAt: nil
                ))
            } else {
                filteredMeds.append(med)
            }
        }
        return (filteredMeds, medicationActions + derivedStops)
    }
}
