// ViewModels/AuthViewModel.swift
import Foundation
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    init() {
        userSession = Auth.auth().currentUser
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.userSession = user
        }
    }

    func signIn(withEmail email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }

    func createUser(
        withEmail email: String,
        password: String,
        firstName: String,
        lastName: String,
        dob: String,
        gender: String,
        phoneNumber: String,
        street: String,
        city: String,
        state: String,
        zip: String,
        insuranceProvider: String,
        insuranceMemberId: String,
        allergies: String,
        chronicConditions: String,
        heightFeet: String,
        heightInches: String,
        weight: String
    ) async {
        isLoading = true
        errorMessage = nil
        do {
            
            let allergiesArray = allergies.isEmpty ? [] : allergies.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let chronicConditionsArray = chronicConditions.isEmpty ? [] : chronicConditions.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            let newUser = User(
                email: email,
                firstName: firstName,
                lastName: lastName,
                dob: dob,
                gender: gender,
                phoneNumber: phoneNumber,
                street: street,
                city: city,
                state: state,
                zip: zip,
                insuranceProvider: insuranceProvider,
                insuranceMemberId: insuranceMemberId,
                allergies: allergiesArray,
                chronicConditions: chronicConditionsArray,
                heightFeet: heightFeet,
                heightInches: heightInches,
                weight: weight
            )
            try await OpenCareFirebaseService.shared.signUp(email: email, password: password, userData: newUser)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Registration failed: \(error.localizedDescription)"
            print("[Registration Error] \(error)")
            // Fallback: Prompt user to re-enter profile info if Firestore save failed
            if (error.localizedDescription.contains("user not found") || error.localizedDescription.contains("missing")) {
                errorMessage = "Profile creation failed. Please re-enter your information."
               
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            errorMessage = nil
        } catch {
            self.errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }
}
