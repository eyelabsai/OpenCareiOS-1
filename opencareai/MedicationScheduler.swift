// Services/MedicationScheduler.swift
import Foundation

struct MedicationPhase {
    let phase: Int
    let startDate: Date
    let endDate: Date
    let frequency: Int
    let dosage: Int
    let instruction: String
    let daysRemaining: Int
    let isActive: Bool
    let isCompleted: Bool
}

struct MedicationSchedule {
    let medicationName: String
    let startDate: Date
    let timeline: [MedicationPhase]
    let totalDuration: Int
    let currentPhase: Int
    let overallProgress: Int
    let hasSchedule: Bool
    let type: String
    let message: String?
}

struct MedicationStatus {
    let status: String
    let message: String
    let currentPhase: MedicationPhase?
    let daysRemaining: Int?
    let nextPhase: MedicationPhase?
}

struct DailyScheduleItem {
    let time: String
    let dosage: Int
    let instruction: String
    let taken: Bool
    let scheduledDateTime: Date
}

struct DailySchedule {
    let date: Date
    let phase: MedicationPhase
    let schedule: [DailyScheduleItem]
    let totalDoses: Int
}

class MedicationScheduler: ObservableObject {
    private let currentDate = Date()
    
    // Parse tapering instructions and create timeline
    func parseTaperingRegimen(medication: Medication) -> MedicationSchedule? {
        let fullInstructions = medication.fullInstructions ?? ""
        
        // Smart start date detection
        let actualStartDate = determineStartDate(fullInstructions: fullInstructions, startDate: medication.createdAt, visitDate: medication.createdAt)
        
        let timeline = [MedicationPhase]()
        
        
        let patterns = [
            
            try! NSRegularExpression(pattern: "(\\d+)x?\\s*(?:times?\\s*)?(?:daily|per\\s*day|a\\s*day)\\s*for\\s*(\\d+)\\s*(?:week|wk)s?", options: .caseInsensitive),
            
            
            try! NSRegularExpression(pattern: "(\\d+)\\s*drops?\\s*(\\d+)\\s*times?\\s*daily\\s*for\\s*(\\d+)\\s*(?:week|wk)s?", options: .caseInsensitive),
            
          
            try! NSRegularExpression(pattern: "(?:apply\\s*)?(\\d+)x\\s*daily\\s*x\\s*(\\d+)\\s*(?:week|wk)s?", options: .caseInsensitive),
            
           
            try! NSRegularExpression(pattern: "(\\d+)\\s*times?\\s*per\\s*day\\s*for\\s*(\\d+)\\s*days?", options: .caseInsensitive)
        ]
        
        var currentDate = actualStartDate
        var matches: [NSTextCheckingResult] = []
        
 
        for pattern in patterns {
            let range = NSRange(location: 0, length: fullInstructions.count)
            let patternMatches = pattern.matches(in: fullInstructions, range: range)
            if !patternMatches.isEmpty {
                matches = patternMatches
                break
            }
        }
        
        if matches.isEmpty {
           
            return createSimpleSchedule(medication: medication, startDate: actualStartDate)
        }
        
       
        var phases: [MedicationPhase] = []
        for (index, match) in matches.enumerated() {
            var frequency: Int = 1
            var duration: Int = 1
            var dosage: Int = 1
            
            if match.numberOfRanges == 3 {
               
                if let frequencyRange = Range(match.range(at: 1), in: fullInstructions),
                   let durationRange = Range(match.range(at: 2), in: fullInstructions) {
                    frequency = Int(fullInstructions[frequencyRange]) ?? 1
                    duration = Int(fullInstructions[durationRange]) ?? 1
                }
            } else if match.numberOfRanges == 4 {
               
                if let dosageRange = Range(match.range(at: 1), in: fullInstructions),
                   let frequencyRange = Range(match.range(at: 2), in: fullInstructions),
                   let durationRange = Range(match.range(at: 3), in: fullInstructions) {
                    dosage = Int(fullInstructions[dosageRange]) ?? 1
                    frequency = Int(fullInstructions[frequencyRange]) ?? 1
                    duration = Int(fullInstructions[durationRange]) ?? 1
                }
            }
            
            let phaseEndDate = Calendar.current.date(byAdding: .day, value: duration * 7, to: currentDate) ?? currentDate
            
            let phase = MedicationPhase(
                phase: index + 1,
                startDate: currentDate,
                endDate: phaseEndDate,
                frequency: frequency,
                dosage: dosage,
                instruction: "\(dosage > 1 ? "\(dosage) drops " : "")\(frequency) times daily",
                daysRemaining: calculateDaysRemaining(startDate: currentDate, durationDays: duration * 7),
                isActive: isPhaseActive(startDate: currentDate, durationDays: duration * 7),
                isCompleted: isPhaseCompleted(startDate: currentDate, durationDays: duration * 7)
            )
            
            phases.append(phase)
            
            // Move to next phase
            currentDate = phaseEndDate
        }
        
        return MedicationSchedule(
            medicationName: medication.name,
            startDate: actualStartDate,
            timeline: phases,
            totalDuration: calculateTotalDuration(timeline: phases),
            currentPhase: getCurrentPhase(timeline: phases),
            overallProgress: calculateOverallProgress(timeline: phases),
            hasSchedule: true,
            type: "tapering",
            message: nil
        )
    }
    
    // Smart start date detection
    private func determineStartDate(fullInstructions: String, startDate: Date?, visitDate: Date?) -> Date {
        // Check if instructions mention "tomorrow", "starting tomorrow", etc.
        let tomorrowPattern = try! NSRegularExpression(pattern: "(?:start(?:ing)?\\s+)?tomorrow|next\\s+day|beginning\\s+tomorrow", options: .caseInsensitive)
        let todayPattern = try! NSRegularExpression(pattern: "(?:start(?:ing)?\\s+)?today|right\\s+now|immediately", options: .caseInsensitive)
        
       
        let visitDateObj = visitDate ?? Date()
        
        let range = NSRange(location: 0, length: fullInstructions.count)
        
        if tomorrowPattern.firstMatch(in: fullInstructions, range: range) != nil {
           
            return Calendar.current.date(byAdding: .day, value: 1, to: visitDateObj) ?? visitDateObj
        } else if todayPattern.firstMatch(in: fullInstructions, range: range) != nil {
            
            return visitDateObj
        } else if let startDate = startDate {
          
            return startDate
        } else {
            
            return visitDateObj
        }
    }
    
    
    private func createSimpleSchedule(medication: Medication, startDate: Date) -> MedicationSchedule? {
        let frequency = medication.frequency
        let duration = medication.duration ?? ""
        let fullInstructions = medication.fullInstructions ?? ""
        
        if frequency.isEmpty && fullInstructions.isEmpty { return nil }
        
        
        let timesPerDay = frequency.isEmpty ? extractFrequency(instructions: fullInstructions) : (Int(frequency) ?? 1)
        let durationDays = duration.isEmpty ? (extractDuration(instructions: fullInstructions) ?? 7) : (Int(duration) ?? 7)
        
        let endDate = Calendar.current.date(byAdding: .day, value: durationDays, to: startDate) ?? startDate
        
        let phase = MedicationPhase(
            phase: 1,
            startDate: startDate,
            endDate: endDate,
            frequency: timesPerDay,
            dosage: 1,
            instruction: fullInstructions.isEmpty ? "\(timesPerDay) times daily" : fullInstructions,
            daysRemaining: calculateDaysRemaining(startDate: startDate, durationDays: durationDays),
            isActive: isPhaseActive(startDate: startDate, durationDays: durationDays),
            isCompleted: isPhaseCompleted(startDate: startDate, durationDays: durationDays)
        )
        
        return MedicationSchedule(
            medicationName: medication.name,
            startDate: startDate,
            timeline: [phase],
            totalDuration: durationDays,
            currentPhase: 1,
            overallProgress: calculateProgress(startDate: startDate, endDate: endDate),
            hasSchedule: true,
            type: "short-term",
            message: nil
        )
    }
    
    // Helper functions
    private func extractFrequency(instructions: String) -> Int {
        let frequencyMatch = instructions.range(of: "(\\d+)\\s*(?:times?|x)", options: .regularExpression)
        if let match = frequencyMatch {
            let frequencyString = String(instructions[match])
            let numberMatch = frequencyString.range(of: "\\d+", options: .regularExpression)
            if let numberRange = numberMatch {
                return Int(String(frequencyString[numberRange])) ?? 1
            }
        }
        return 1
    }
    
    private func extractDuration(instructions: String) -> Int? {
        let weekMatch = instructions.range(of: "(\\d+)\\s*(?:week|wk)s?", options: .regularExpression)
        if let match = weekMatch {
            let weekString = String(instructions[match])
            let numberMatch = weekString.range(of: "\\d+", options: .regularExpression)
            if let numberRange = numberMatch {
                return (Int(String(weekString[numberRange])) ?? 1) * 7
            }
        }
        
        let dayMatch = instructions.range(of: "(\\d+)\\s*days?", options: .regularExpression)
        if let match = dayMatch {
            let dayString = String(instructions[match])
            let numberMatch = dayString.range(of: "\\d+", options: .regularExpression)
            if let numberRange = numberMatch {
                return Int(String(dayString[numberRange])) ?? 7
            }
        }
        
        return nil
    }
    
    private func calculateDaysRemaining(startDate: Date, durationDays: Int) -> Int {
        let endDate = Calendar.current.date(byAdding: .day, value: durationDays, to: startDate) ?? startDate
        let today = Date()
        let diffTime = endDate.timeIntervalSince(today)
        let diffDays = Int(ceil(diffTime / (24 * 60 * 60)))
        return max(0, diffDays)
    }
    
    private func isPhaseActive(startDate: Date, durationDays: Int) -> Bool {
        let today = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: durationDays, to: startDate) ?? startDate
        return today >= startDate && today <= endDate
    }
    
    private func isPhaseCompleted(startDate: Date, durationDays: Int) -> Bool {
        let today = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: durationDays, to: startDate) ?? startDate
        return today > endDate
    }
    
    private func calculateTotalDuration(timeline: [MedicationPhase]) -> Int {
        return timeline.reduce(0) { total, phase in
            let phaseDuration = Calendar.current.dateComponents([.day], from: phase.startDate, to: phase.endDate).day ?? 0
            return total + phaseDuration
        }
    }
    
    private func getCurrentPhase(timeline: [MedicationPhase]) -> Int {
        for (index, phase) in timeline.enumerated() {
            if phase.isActive {
                return index + 1
            }
        }
        return timeline.count // All phases completed or not started
    }
    
    private func calculateOverallProgress(timeline: [MedicationPhase]) -> Int {
        let totalDays = calculateTotalDuration(timeline: timeline)
        if totalDays == 0 { return 0 }
        
        let completedDays = timeline.reduce(0) { completed, phase in
            if phase.isCompleted {
                let phaseDuration = Calendar.current.dateComponents([.day], from: phase.startDate, to: phase.endDate).day ?? 0
                return completed + phaseDuration
            } else if phase.isActive {
                let today = Date()
                let elapsedDays = Calendar.current.dateComponents([.day], from: phase.startDate, to: today).day ?? 0
                return completed + elapsedDays
            }
            return completed
        }
        
        let progress = (Double(completedDays) / Double(totalDays)) * 100
        return min(100, max(0, Int(round(progress))))
    }
    
    private func calculateProgress(startDate: Date, endDate: Date) -> Int {
        let today = Date()
        let totalDuration = endDate.timeIntervalSince(startDate)
        if totalDuration == 0 { return 0 }
        
        let elapsed = today.timeIntervalSince(startDate)
        let progress = (elapsed / totalDuration) * 100
        return min(100, max(0, Int(round(progress))))
    }
    
    // Format date for display
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
    
    func formatDateLong(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }
    
    // Get medication status
    func getMedicationStatus(medicationSchedule: MedicationSchedule) -> MedicationStatus {
        let today = Date()
        let currentPhase = medicationSchedule.timeline.first { $0.isActive }
        
        if currentPhase == nil {
            let isCompleted = medicationSchedule.timeline.allSatisfy { $0.isCompleted }
            let hasStarted = medicationSchedule.timeline.contains { $0.isCompleted || $0.isActive }
            
            if isCompleted {
                return MedicationStatus(
                    status: "completed",
                    message: "Treatment completed",
                    currentPhase: nil,
                    daysRemaining: nil,
                    nextPhase: nil
                )
            } else if !hasStarted {
                let nextPhase = medicationSchedule.timeline.first
                return MedicationStatus(
                    status: "not-started",
                    message: "Starts \(formatDate(nextPhase?.startDate ?? today))",
                    currentPhase: nil,
                    daysRemaining: nil,
                    nextPhase: nextPhase
                )
            }
        }
        
        if let currentPhase = currentPhase {
            return MedicationStatus(
                status: "active",
                message: "Phase \(currentPhase.phase): \(currentPhase.instruction)",
                currentPhase: currentPhase,
                daysRemaining: currentPhase.daysRemaining,
                nextPhase: nil
            )
        }
        
        // Fallback for edge cases
        return MedicationStatus(
            status: "unknown",
            message: "Status unavailable",
            currentPhase: nil,
            daysRemaining: nil,
            nextPhase: nil
        )
    }
    
    // UNIVERSAL MEDICATION CLASSIFICATION METHODS
    func classifyMedicationType(medication: Medication) -> (type: String, hasTimeline: Bool, showProgress: Bool, reason: String) {
        let fullInstructions = medication.fullInstructions ?? ""
        
        // First check if it's a clear tapering regimen
        if isTaperingRegimen(instructions: fullInstructions) {
            return ("tapering", true, true, "Contains specific tapering instructions")
        }
        
        
        if hasAmbiguousEndCondition(instructions: fullInstructions) {
            return ("chronic", false, false, "Contains ambiguous end condition without specific date")
        }
        
        // Check for specific duration
        if hasSpecificDuration(instructions: fullInstructions) {
            return ("short-term", true, true, "Contains specific duration")
        }
        
        // Default to chronic if no clear timeline
        return ("chronic", false, false, "No clear timeline indicators - assuming chronic")
    }
    
    // UNIVERSAL PATTERN: Detect "until [something happens]" without specific dates
    private func hasAmbiguousEndCondition(instructions: String) -> Bool {
        let ambiguousPatterns = [
            // Pattern: "until [condition] [improves/resolves/normalizes/etc]"
            try! NSRegularExpression(pattern: "until\\s+(?:we\\s+see\\s+)?(?:your\\s+)?[\\w\\s]+\\s+(?:improve|resolve|normalize|stabilize|clear|heal|get\\s+better|go\\s+away|disappear|subside)", options: .caseInsensitive),
            
            // Pattern: "until [condition] is [state]"
            try! NSRegularExpression(pattern: "until\\s+(?:we\\s+see\\s+)?(?:your\\s+)?[\\w\\s]+\\s+is\\s+(?:normal|stable|controlled|clear|healed|better|gone)", options: .caseInsensitive),
            
            // Pattern: "until no more [condition]"
            try! NSRegularExpression(pattern: "until\\s+(?:we\\s+see\\s+)?(?:no\\s+more\\s+|there\\s+are\\s+no\\s+more\\s+)[\\w\\s]+", options: .caseInsensitive),
            
            // Pattern: "until [condition] stops/ends"
            try! NSRegularExpression(pattern: "until\\s+(?:the\\s+)?[\\w\\s]+\\s+(?:stops?|ends?|goes\\s+away|disappears?)", options: .caseInsensitive),
            
            // Pattern: "until you feel [better/normal/etc]"
            try! NSRegularExpression(pattern: "until\\s+you\\s+feel\\s+(?:better|normal|fine|good|well)", options: .caseInsensitive),
            
            // Pattern: "until further notice/evaluation"
            try! NSRegularExpression(pattern: "until\\s+(?:further\\s+)?(?:notice|evaluation|assessment|review|follow.?up)", options: .caseInsensitive),
            
            // Pattern: "or until [anything]" - the "or" makes it ambiguous
            try! NSRegularExpression(pattern: "or\\s+until\\s+[\\w\\s]+", options: .caseInsensitive)
        ]
        
        let range = NSRange(location: 0, length: instructions.count)
        return ambiguousPatterns.contains { pattern in
            pattern.firstMatch(in: instructions, range: range) != nil
        }
    }
    
    // Check for specific, measurable durations
    private func hasSpecificDuration(instructions: String) -> Bool {
        let specificDurationPatterns = [
            // Exact time periods with numbers
            try! NSRegularExpression(pattern: "(?:for\\s+)?(?:exactly\\s+)?\\d+\\s+(?:days?|weeks?|months?)", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "(?:for\\s+)?(?:the\\s+next\\s+)?\\d+\\s+(?:days?|weeks?|months?)", options: .caseInsensitive),
            
            // Exact time periods with written numbers
            try! NSRegularExpression(pattern: "(?:for\\s+)?(?:exactly\\s+)?(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\\s+(?:more\\s+)?(?:days?|weeks?|months?)", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "(?:for\\s+)?(?:the\\s+next\\s+)?(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\\s+(?:days?|weeks?|months?)", options: .caseInsensitive),
            
            // "X more days" patterns
            try! NSRegularExpression(pattern: "\\d+\\s+more\\s+(?:days?|weeks?|months?)", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\\s+more\\s+(?:days?|weeks?|months?)", options: .caseInsensitive),
            
            // Course completion
            try! NSRegularExpression(pattern: "complete\\s+(?:the\\s+)?(?:full\\s+)?course", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "finish\\s+(?:all\\s+)?(?:the\\s+)?(?:pills?|tablets?|medication)", options: .caseInsensitive),
            
            // Specific end dates
            try! NSRegularExpression(pattern: "until\\s+(?:january|february|march|april|may|june|july|august|september|october|november|december)", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "until\\s+\\d+\\/\\d+", options: .caseInsensitive),
            
            // Post-procedure with specific timeframes
            try! NSRegularExpression(pattern: "for\\s+\\d+\\s+(?:days?|weeks?)\\s+(?:after|following|post)", options: .caseInsensitive),
            
            // Additional specific duration patterns
            try! NSRegularExpression(pattern: "(?:continue\\s+)?(?:for\\s+)?(?:another\\s+)?\\d+\\s+(?:days?|weeks?|months?)", options: .caseInsensitive),
            try! NSRegularExpression(pattern: "(?:continue\\s+)?(?:for\\s+)?(?:another\\s+)?(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\\s+(?:days?|weeks?|months?)", options: .caseInsensitive)
        ]
        
        let range = NSRange(location: 0, length: instructions.count)
        return specificDurationPatterns.contains { pattern in
            pattern.firstMatch(in: instructions, range: range) != nil
        }
    }
    
    // Check for tapering regimen patterns
    private func isTaperingRegimen(instructions: String) -> Bool {
        let taperingPatterns = [
            // Pattern 1: "4x daily for 1 week, then 3x daily for 1 week"
            try! NSRegularExpression(pattern: "(\\d+)x?\\s*(?:times?\\s*)?(?:daily|per\\s*day|a\\s*day)\\s*for\\s*(\\d+)\\s*(?:week|wk)s?.*then", options: .caseInsensitive),
            
            // Pattern 2: "1 drop 4 times daily for 1 week, then 3 times daily for 1 week"
            try! NSRegularExpression(pattern: "(\\d+)\\s*drops?\\s*(\\d+)\\s*times?\\s*daily\\s*for\\s*(\\d+)\\s*(?:week|wk)s?.*then", options: .caseInsensitive),
            
            // Pattern 3: "Apply 4x daily x 1 week, then 3x daily x 1 week"
            try! NSRegularExpression(pattern: "(?:apply\\s*)?(\\d+)x\\s*daily\\s*x\\s*(\\d+)\\s*(?:week|wk)s?.*then", options: .caseInsensitive),
            
            // Pattern 4: "Use 4 times per day for 7 days, then 3 times per day for 7 days"
            try! NSRegularExpression(pattern: "(\\d+)\\s*times?\\s*per\\s*day\\s*for\\s*(\\d+)\\s*days?.*then", options: .caseInsensitive),
            
            // Multiple frequency changes
            try! NSRegularExpression(pattern: "\\d+\\s*(?:times?\\s*)?(?:daily|per\\s*day).*then.*\\d+\\s*(?:times?\\s*)?(?:daily|per\\s*day)", options: .caseInsensitive),
            
            // Explicit tapering language
            try! NSRegularExpression(pattern: "taper|reduce|decrease|step.?down|wean|gradually", options: .caseInsensitive),
            
            // Start high, go low pattern
            try! NSRegularExpression(pattern: "(?:start|begin)\\s+(?:with\\s+)?\\d+.*(?:reduce|decrease|then\\s+\\d+)", options: .caseInsensitive)
        ]
        
        let range = NSRange(location: 0, length: instructions.count)
        return taperingPatterns.contains { pattern in
            pattern.firstMatch(in: instructions, range: range) != nil
        }
    }
    
    // Enhanced medication processing with universal classification
    func processUniversalMedication(medication: Medication) -> MedicationSchedule? {
        let classification = classifyMedicationType(medication: medication)
        
        if classification.type == "tapering" {
            return parseTaperingRegimen(medication: medication)
        }
        
        if classification.type == "short-term" {
            // Use createdAt if available, otherwise fall back to current date
            let startDate = medication.createdAt ?? Date()
            return createSimpleSchedule(medication: medication, startDate: startDate)
        }
        
        // For chronic medications, return simple display without timeline
        return MedicationSchedule(
            medicationName: medication.name,
            startDate: Date(),
            timeline: [],
            totalDuration: 0,
            currentPhase: 0,
            overallProgress: 0,
            hasSchedule: false,
            type: "chronic",
            message: "Continue as prescribed - no specific end date"
        )
    }
    
    // Generate daily schedule for a specific date
    func generateDailySchedule(medicationSchedule: MedicationSchedule, date: Date) -> DailySchedule? {
        let targetDate = date
        let currentPhase = medicationSchedule.timeline.first { phase in
            targetDate >= phase.startDate && targetDate <= phase.endDate
        }
        
        guard let phase = currentPhase else { return nil }
        
        let schedule = generateSuggestedTimes(frequency: phase.frequency).map { time in
            DailyScheduleItem(
                time: time.label,
                dosage: phase.dosage,
                instruction: phase.instruction,
                taken: false, // This would be tracked in the database
                scheduledDateTime: Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: targetDate) ?? targetDate
            )
        }
        
        return DailySchedule(
            date: targetDate,
            phase: phase,
            schedule: schedule,
            totalDoses: phase.frequency
        )
    }
    
    private func generateSuggestedTimes(frequency: Int) -> [(hour: Int, minute: Int, label: String)] {
        var times: [(hour: Int, minute: Int, label: String)] = []
        
        switch frequency {
        case 1:
            times.append((hour: 8, minute: 0, label: "8:00 AM"))
        case 2:
            times.append((hour: 8, minute: 0, label: "8:00 AM"))
            times.append((hour: 20, minute: 0, label: "8:00 PM"))
        case 3:
            times.append((hour: 8, minute: 0, label: "8:00 AM"))
            times.append((hour: 14, minute: 0, label: "2:00 PM"))
            times.append((hour: 20, minute: 0, label: "8:00 PM"))
        case 4:
            times.append((hour: 8, minute: 0, label: "8:00 AM"))
            times.append((hour: 12, minute: 0, label: "12:00 PM"))
            times.append((hour: 18, minute: 0, label: "6:00 PM"))
            times.append((hour: 22, minute: 0, label: "10:00 PM"))
        default:
            // For higher frequencies, distribute evenly
            let interval = 24 / frequency
            for i in 0..<frequency {
                let hour = (8 + (i * interval)) % 24
                let ampm = hour >= 12 ? "PM" : "AM"
                let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
                times.append((hour: hour, minute: 0, label: "\(displayHour):00 \(ampm)"))
            }
        }
        
        return times
    }
} 
