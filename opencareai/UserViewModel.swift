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
    
    private let firebaseService = OpenCareFirebaseService.shared
    
    func fetchUserProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let userId = Auth.auth().currentUser?.uid ?? ""
            let fetchedUser = try await firebaseService.getUserData(userId: userId)
            self.user = fetchedUser
        } catch {
            errorMessage = "Failed to fetch profile: \(error.localizedDescription)"
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