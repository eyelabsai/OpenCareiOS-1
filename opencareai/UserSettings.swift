//
//  UserSettings.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/21/25.
//


import Foundation
import Combine

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    // Define keys for UserDefaults
    private enum Keys {
        static let morningTime = "morningTime"
        static let afternoonTime = "afternoonTime"
        static let eveningTime = "eveningTime"
        static let bedtimeTime = "bedtimeTime"
    }
    
    // Use @Published to automatically update any views using these settings
    @Published var morningTime: Date {
        didSet { UserDefaults.standard.set(morningTime.timeIntervalSinceReferenceDate, forKey: Keys.morningTime) }
    }
    
    @Published var afternoonTime: Date {
        didSet { UserDefaults.standard.set(afternoonTime.timeIntervalSinceReferenceDate, forKey: Keys.afternoonTime) }
    }
    
    @Published var eveningTime: Date {
        didSet { UserDefaults.standard.set(eveningTime.timeIntervalSinceReferenceDate, forKey: Keys.eveningTime) }
    }
    
    @Published var bedtimeTime: Date {
        didSet { UserDefaults.standard.set(bedtimeTime.timeIntervalSinceReferenceDate, forKey: Keys.bedtimeTime) }
    }
    
    private init() {
        // Load saved times or set defaults
        let defaults = UserDefaults.standard
        
        // Default times: Morning (8 AM), Afternoon (1 PM), Evening (6 PM), Bedtime (10 PM)
        self.morningTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Keys.morningTime)) != Date() ? Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Keys.morningTime)) : Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        self.afternoonTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Keys.afternoonTime)) != Date() ? Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Keys.afternoonTime)) : Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date())!
        self.eveningTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Keys.eveningTime)) != Date() ? Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Keys.eveningTime)) : Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!
        self.bedtimeTime = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Keys.bedtimeTime)) != Date() ? Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Keys.bedtimeTime)) : Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!
    }
}