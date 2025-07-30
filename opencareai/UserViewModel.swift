//
//  UserViewModel.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/3/25.
//


// ViewModels/UserViewModel.swift
import Foundation
import FirebaseAuth

@MainActor
class UserViewModel: ObservableObject {
    @Published var user = User(
        email: "",
        firstName: "",
        lastName: "",
        dob: "",
        gender: "",
        phoneNumber: "",
        street: "",
        city: "",
        state: "",
        zip: "",
        insuranceProvider: "",
        insuranceMemberId: "",
        allergies: [],
        chronicConditions: [],
        heightFeet: "",
        heightInches: "",
        weight: "",
        emergencyContactName: "",
        emergencyContactPhone: "",
        primaryPhysician: "",
        bloodType: ""
    )
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingProfileRecovery: Bool = false
    
    private let firebaseService = OpenCareFirebaseService.shared
    
    func fetchUserProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let currentUser = Auth.auth().currentUser else {
                throw FirebaseError.userNotFound
            }
            
            let fetchedUser = try await firebaseService.getUserData(userId: currentUser.uid)
            self.user = fetchedUser
            showingProfileRecovery = false
            
        } catch {
            print("Profile fetch error: \(error.localizedDescription)")
            
            // Check if it's a missing profile error
            if error.localizedDescription.contains("User not found") {
                await handleMissingProfile()
            } else {
                errorMessage = "Failed to fetch profile: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    private func handleMissingProfile() async {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "Authentication error - please sign in again"
            return
        }
        
        print("Profile not found, attempting to create basic profile...")
        
        // Try to create a basic profile from auth data
        do {
            let basicUser = User(
                id: currentUser.uid,
                email: currentUser.email ?? "",
                firstName: currentUser.displayName?.components(separatedBy: " ").first ?? "",
                lastName: currentUser.displayName?.components(separatedBy: " ").dropFirst().joined(separator: " ") ?? "",
                dob: "",
                gender: "",
                phoneNumber: currentUser.phoneNumber ?? "",
                street: "",
                city: "",
                state: "",
                zip: "",
                insuranceProvider: "",
                insuranceMemberId: "",
                allergies: [],
                chronicConditions: [],
                heightFeet: "",
                heightInches: "",
                weight: "",
                emergencyContactName: "",
                emergencyContactPhone: "",
                primaryPhysician: "",
                bloodType: "",
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // Save the basic profile
            try await firebaseService.updateUser(basicUser)
            self.user = basicUser
            errorMessage = "Profile recovered! Please complete your information below."
            showingProfileRecovery = true
            
        } catch {
            print("Failed to create basic profile: \(error.localizedDescription)")
            errorMessage = "Profile not found. Please complete your profile information."
            showingProfileRecovery = true
        }
    }
    
    func createMissingProfile() async {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "Authentication error - please sign in again"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var newUser = user
            newUser.id = currentUser.uid
            newUser.email = currentUser.email ?? user.email
            newUser.createdAt = Date()
            newUser.updatedAt = Date()
            
            try await firebaseService.updateUser(newUser)
            self.user = newUser
            showingProfileRecovery = false
            errorMessage = nil
            
        } catch {
            errorMessage = "Failed to create profile: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateUserProfile() async {
        isLoading = true
        errorMessage = nil
        
        var updatedUser = user
        updatedUser.updatedAt = Date()
        
        do {
            try await firebaseService.updateUser(updatedUser)
            self.user = updatedUser
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func addCondition(_ condition: String) async {
        let trimmedCondition = condition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCondition.isEmpty else { return }
        
        if !user.chronicConditions.contains(trimmedCondition) {
            user.chronicConditions.append(trimmedCondition)
            await updateUserProfile()
        }
    }
    
    func removeCondition(_ condition: String) async {
        user.chronicConditions.removeAll { $0 == condition }
        await updateUserProfile()
    }
    
    func addAllergy(_ allergy: String) async {
        let trimmedAllergy = allergy.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAllergy.isEmpty else { return }
        
        if !user.allergies.contains(trimmedAllergy) {
            user.allergies.append(trimmedAllergy)
            await updateUserProfile()
        }
    }
    
    func removeAllergy(_ allergy: String) async {
        user.allergies.removeAll { $0 == allergy }
        await updateUserProfile()
    }
}