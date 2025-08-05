// ViewModels/AuthViewModel.swift
import Foundation
import FirebaseAuth
import LocalAuthentication

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var passwordResetSent: Bool = false

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

    // Simplified user creation for basic registration
    func createUser(
        withEmail email: String,
        password: String,
        firstName: String,
        lastName: String
    ) async {
        isLoading = true
        errorMessage = nil
        do {
            let newUser = User(
                email: email,
                firstName: firstName,
                lastName: lastName
            )
            try await OpenCareFirebaseService.shared.signUp(email: email, password: password, userData: newUser)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Registration failed: \(error.localizedDescription)"
            print("[Registration Error] \(error)")
        }
    }

    // Full user creation with all details (for profile completion)
    func createUserWithFullDetails(
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
    
    func sendPasswordReset(email: String) async {
        isLoading = true
        errorMessage = nil
        passwordResetSent = false
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            passwordResetSent = true
            errorMessage = nil
        } catch {
            errorMessage = "Failed to send password reset: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func deleteAccount() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let userId = userSession?.uid else {
                throw FirebaseError.userNotFound
            }
            
            // Check if user was recently authenticated (within 5 minutes)
            if let metadata = userSession?.metadata,
               let lastSignInTime = metadata.lastSignInDate,
               Date().timeIntervalSince(lastSignInTime) < 300 { // 5 minutes
                
                print("User recently authenticated, proceeding with deletion")
                try await OpenCareFirebaseService.shared.deleteAccount(userId: userId)
                print("Account deletion completed successfully")
                errorMessage = nil
                return
            }
            
            // If not recently authenticated, we need reauthentication
            errorMessage = "Please confirm your identity to delete your account."
            
        } catch {
            print("Account deletion failed: \(error.localizedDescription)")
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func deleteAccountWithBiometrics() async {
        isLoading = true
        errorMessage = nil
        
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            errorMessage = "Biometric authentication not available"
            isLoading = false
            return
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to delete your account"
            )
            
            if success {
                guard let userId = userSession?.uid else {
                    throw FirebaseError.userNotFound
                }
                
                print("Biometric authentication successful, proceeding with deletion")
                try await OpenCareFirebaseService.shared.deleteAccount(userId: userId)
                print("Account deletion completed successfully")
                errorMessage = nil
            }
            
        } catch {
            print("Biometric authentication or deletion failed: \(error.localizedDescription)")
            errorMessage = "Authentication failed or account deletion error"
        }
        
        isLoading = false
    }
    
    func reauthenticateAndDeleteAccount(password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let user = userSession,
                  let email = user.email else {
                throw FirebaseError.userNotFound
            }
            
            // Re-authenticate the user
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
            print("Re-authentication successful")
            
            // Now proceed with account deletion
            try await OpenCareFirebaseService.shared.deleteAccount(userId: user.uid)
            print("Account deletion completed successfully")
            errorMessage = nil
            
        } catch {
            print("Re-authentication or account deletion failed: \(error.localizedDescription)")
            if error.localizedDescription.contains("wrong-password") {
                errorMessage = "Incorrect password. Please try again."
            } else {
                errorMessage = "Failed to delete account: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}
