//
//  Config.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/3/25.
//


// Config.swift
import Foundation

struct Config {
    // API Configuration
    static let apiBaseURL = "http://localhost:3000/api" // Update this to match your web app server
    
    // Firebase Configuration
    static let firebaseConfig = [
        "apiKey": "your-api-key",
        "authDomain": "your-project.firebaseapp.com",
        "projectId": "your-project-id",
        "storageBucket": "your-project.appspot.com",
        "messagingSenderId": "your-sender-id",
        "appId": "your-app-id"
    ]
    
    // App Configuration
    static let appName = "OpenCare"
    static let appVersion = "1.0.0"
    static let buildNumber = "1"
    
    // Feature Flags
    static let enableHealthAssistant = true
    static let enableMedicationScheduler = true
    static let enableVisitHistory = true
    static let enableProfileManagement = true
    
    // UI Configuration
    static let maxRecordingDuration: TimeInterval = 300 // 5 minutes
    static let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB
    
    // Default Values
    static let defaultSpecialties = [
        "Primary Care",
        "Cardiology",
        "Dermatology",
        "Endocrinology",
        "Gastroenterology",
        "Neurology",
        "Oncology",
        "Ophthalmology",
        "Orthopedics",
        "Psychiatry",
        "Rheumatology",
        "Urology",
        "Other"
    ]
    
    static let defaultMedicationRoutes = [
        "Oral",
        "Topical",
        "Inhalation",
        "Injection",
        "Eye Drops",
        "Ear Drops",
        "Nasal",
        "Other"
    ]
    
    static let defaultMedicationFrequencies = [
        "Once daily",
        "Twice daily",
        "Three times daily",
        "Four times daily",
        "Every 6 hours",
        "Every 8 hours",
        "Every 12 hours",
        "As needed",
        "Other"
    ]
    
    static let defaultMedicationTimings = [
        "Morning",
        "Evening",
        "Before meals",
        "After meals",
        "Before bed",
        "With food",
        "On empty stomach",
        "Other"
    ]
    
    // Error Messages
    static let errorMessages = [
        "networkError": "Please check your internet connection and try again.",
        "authenticationError": "Please sign in again to continue.",
        "permissionError": "You don't have permission to perform this action.",
        "serverError": "Something went wrong on our end. Please try again later.",
        "validationError": "Please check your input and try again."
    ]
    
    // Success Messages
    static let successMessages = [
        "visitSaved": "Visit saved successfully!",
        "medicationSaved": "Medication saved successfully!",
        "profileUpdated": "Profile updated successfully!",
        "messageSent": "Message sent successfully!"
    ]
}