// Views/AuthenticationView.swift
import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isSignUp = false
    @State private var currentStep = 1
    @State private var totalSteps = 2
    
    // Registration fields (simplified)
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingForgotPassword = false
    @State private var forgotPasswordEmail = ""
    

    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case firstName, lastName, email, password, confirmPassword
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header (matching web app styling)
                    VStack(spacing: 16) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("OpenCare")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Your AI-Powered Health Assistant")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 50)
                    
                    if isSignUp {
                        // Enhanced progress indicator (matching web app)
                        VStack(spacing: 12) {
                            // Progress bar
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: CGFloat(currentStep) / CGFloat(totalSteps) * UIScreen.main.bounds.width * 0.8, height: 8)
                                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                            }
                            
                            Text("Step \(currentStep) of \(totalSteps)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 30)
                        
                        // Multi-step registration form
                        registrationForm
                    } else {
                        // Enhanced login form (matching web app)
                        loginForm
                    }
                    
                    Spacer()
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color.blue.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarHidden(true)
        }
    }
    
    private var loginForm: some View {
        VStack(spacing: 24) {
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(EnhancedTextFieldStyle())
                    .focused($focusedField, equals: .email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(EnhancedTextFieldStyle())
                    .focused($focusedField, equals: .password)
                    .textContentType(.password)
                
                // Forgot Password Button
                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        forgotPasswordEmail = email
                        showingForgotPassword = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Password reset success message
            if viewModel.passwordResetSent {
                Text("Password reset email sent! Check your inbox.")
                    .foregroundColor(.green)
                    .font(.caption)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Enhanced sign in button (matching web app)
            Button(action: handleSignIn) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "person.fill")
                    }
                    
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    isLoginFormValid ? 
                    LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .disabled(!isLoginFormValid || viewModel.isLoading)
            
            // Toggle to sign up
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSignUp.toggle()
                    clearForm()
                }
            }) {
                Text("Don't have an account? Sign Up")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .underline()
            }
        }
        .padding(.horizontal, 30)
        .alert("Reset Password", isPresented: $showingForgotPassword) {
            TextField("Email", text: $forgotPasswordEmail)
            Button("Send Reset Link") {
                Task {
                    await viewModel.sendPasswordReset(email: forgotPasswordEmail)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter your email address to receive a password reset link.")
        }

    }
    
    private var registrationForm: some View {
        VStack(spacing: 20) {
            Group {
                switch currentStep {
                case 1:
                    simplifiedBasicInfoStep
                case 2:
                    accountSetupStep
                default:
                    EmptyView()
                }
            }
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Navigation buttons
            HStack(spacing: 12) {
                if currentStep > 1 {
                    Button("Previous") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentStep < totalSteps {
                    Button("Next") {
                        if validateCurrentStep() {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isCurrentStepValid)
                } else {
                    Button(action: handleRegistration) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "person.badge.plus")
                            }
                            
                            Text("Complete Registration")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRegistrationFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isRegistrationFormValid || viewModel.isLoading)
                }
            }
            
            // Toggle to sign in
            Button(action: {
                withAnimation {
                    isSignUp.toggle()
                    clearForm()
                }
            }) {
                Text("Already have an account? Sign In")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 30)
    }
    
    // Step 1: Simplified Basic Information (First and Last Name only)
    private var simplifiedBasicInfoStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Let's start with your basic information. You can complete your full profile later.")
                        .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            
            VStack(spacing: 12) {
                HStack {
                    TextField("First Name", text: $firstName)
                        .textFieldStyle(EnhancedTextFieldStyle())
                        .focused($focusedField, equals: .firstName)
                        .textContentType(.givenName)
                    
                    TextField("Last Name", text: $lastName)
                        .textFieldStyle(EnhancedTextFieldStyle())
                        .focused($focusedField, equals: .lastName)
                        .textContentType(.familyName)
                }
            }
        }
    }
    

    

    

    

    

    

    
    // Step 2: Account Setup
    private var accountSetupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Your Account")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("You can complete your full profile (address, insurance, medical history) later in the Profile section or sync with Apple Health.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(EnhancedTextFieldStyle())
                    .focused($focusedField, equals: .email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(EnhancedTextFieldStyle())
                    .focused($focusedField, equals: .password)
                    .textContentType(.newPassword)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(EnhancedTextFieldStyle())
                    .focused($focusedField, equals: .confirmPassword)
                    .textContentType(.newPassword)
                
                // Password requirements
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password Requirements:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: password.count >= 6 ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(password.count >= 6 ? .green : .gray)
                            .font(.caption)
                        Text("At least 6 characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: password == confirmPassword && !password.isEmpty ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(password == confirmPassword && !password.isEmpty ? .green : .gray)
                            .font(.caption)
                        Text("Passwords match")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    // Validation
    private var isLoginFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        email.contains("@") && 
        password.count >= 6
    }
    
    private var isRegistrationFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword &&
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 1:
            return !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2:
            return isRegistrationFormValid
        default:
            return true
        }
    }
    
    private func validateCurrentStep() -> Bool {
        return isCurrentStepValid
    }
    
    private func handleSignIn() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await viewModel.signIn(withEmail: trimmedEmail, password: trimmedPassword)
        }
    }
    
    private func handleRegistration() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            await viewModel.createUser(
                withEmail: trimmedEmail,
                password: trimmedPassword,
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
    
    private func clearForm() {
        firstName = ""
        lastName = ""
        email = ""
        password = ""
        confirmPassword = ""
        currentStep = 1
        viewModel.errorMessage = nil
        focusedField = nil
    }
    

}
