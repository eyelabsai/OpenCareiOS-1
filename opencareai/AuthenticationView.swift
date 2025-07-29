// Views/AuthenticationView.swift
import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isSignUp = false
    @State private var currentStep = 1
    @State private var totalSteps = 7
    
    // Registration fields (matching web app)
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dob = Date()
    @State private var gender = ""
    @State private var phoneNumber = ""
    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var insuranceProvider = ""
    @State private var insuranceMemberId = ""
    @State private var allergies = ""
    @State private var heightFeet = ""
    @State private var heightInches = ""
    @State private var weight = ""
    @State private var selectedConditions = Set<String>()
    @State private var otherConditions = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // Options (matching web app)
    private let genderOptions = ["", "Male", "Female", "Other", "Prefer not to say"]
    private let insuranceOptions = ["", "Aetna", "Blue Cross", "Cigna", "UnitedHealthcare", "Kaiser", "None", "Other"]
    private let stateOptions = ["", "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]
    private let chronicConditions = ["Hypertension", "Diabetes", "Asthma", "Heart Disease", "Arthritis", "Depression", "Anxiety", "Obesity", "High Cholesterol", "Thyroid Disease", "Cancer", "Stroke", "Kidney Disease", "Liver Disease", "COPD", "Epilepsy", "Migraine", "Fibromyalgia", "Lupus", "Multiple Sclerosis"]
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case firstName, lastName, phone, street, city, zip, insuranceMemberId, allergies, otherConditions, email, password, confirmPassword
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
    }
    
    private var registrationForm: some View {
        VStack(spacing: 20) {
            Group {
                switch currentStep {
                case 1:
                    basicInfoStep
                case 2:
                    addressStep
                case 3:
                    insuranceStep
                case 4:
                    allergiesStep
                case 5:
                    physicalMeasurementsStep
                case 6:
                    chronicConditionsStep
                case 7:
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
    
    // Step 1: Basic Information
    private var basicInfoStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
            Button(action: syncWithHealthKitForRegistration) {
                            HStack {
                                Image(systemName: "heart.fill")
                                Text("Sync with Health")
                            }
                            .font(.caption)
                        }
            
            VStack(spacing: 12) {
                HStack {
                    TextField("First Name", text: $firstName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($focusedField, equals: .firstName)
                        .textContentType(.givenName)
                    
                    TextField("Last Name", text: $lastName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($focusedField, equals: .lastName)
                        .textContentType(.familyName)
                }
                
                DatePicker("Date of Birth", selection: $dob, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                
                Picker("Gender", selection: $gender) {
                    ForEach(genderOptions, id: \.self) { option in
                        Text(option.isEmpty ? "Select Gender" : option).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                TextField("Phone Number", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            }
        }
    }
    
    // Step 2: Address Information
    private var addressStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Address Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                TextField("Street Address", text: $street)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .street)
                    .textContentType(.streetAddressLine1)
                
                HStack {
                    TextField("City", text: $city)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($focusedField, equals: .city)
                        .textContentType(.addressCity)
                    
                    Picker("State", selection: $state) {
                        ForEach(stateOptions, id: \.self) { option in
                            Text(option.isEmpty ? "State" : option).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    TextField("ZIP", text: $zip)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($focusedField, equals: .zip)
                        .textContentType(.postalCode)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
        }
    }
    
    // Step 3: Insurance Information
    private var insuranceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insurance Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Picker("Insurance Provider", selection: $insuranceProvider) {
                    ForEach(insuranceOptions, id: \.self) { option in
                        Text(option.isEmpty ? "Select Provider" : option).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                TextField("Insurance Member ID", text: $insuranceMemberId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .insuranceMemberId)
            }
        }
    }
    
    // Step 4: Allergies
    private var allergiesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Allergies")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                TextField("Known Allergies", text: $allergies, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .allergies)
                    .lineLimit(3...6)
            }
        }
    }
    
    // Step 5: Physical Measurements
    private var physicalMeasurementsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Physical Measurements")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Height:")
                    Picker("Feet", selection: $heightFeet) {
                        ForEach((4...7).map { String($0) }, id: \.self) { ft in
                            Text("\(ft) ft").tag(ft)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("Inches", selection: $heightInches) {
                        ForEach((0...11).map { String($0) }, id: \.self) { inch in
                            Text("\(inch) in").tag(inch)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                HStack {
                    Text("Weight:")
                    Picker("Weight", selection: $weight) {
                        ForEach((80...400).map { String($0) }, id: \.self) { lbs in
                            Text("\(lbs) lbs").tag(lbs)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
        }
    }
    
    // Step 6: Chronic Conditions
    private var chronicConditionsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chronic Conditions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Text("Select any chronic conditions you have:")
                    .font(.subheadline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(chronicConditions, id: \.self) { condition in
                        Button(action: {
                            if selectedConditions.contains(condition) {
                                selectedConditions.remove(condition)
                            } else {
                                selectedConditions.insert(condition)
                            }
                        }) {
                            Text(condition)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedConditions.contains(condition) ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedConditions.contains(condition) ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                TextField("Other conditions (optional)", text: $otherConditions, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .otherConditions)
                    .lineLimit(2...4)
            }
        }
    }
    
    // Step 7: Account Setup
    private var accountSetupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Setup")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .password)
                    .textContentType(.newPassword)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .confirmPassword)
                    .textContentType(.newPassword)
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
                   !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3:
            return !insuranceProvider.isEmpty
        case 6:
            return !selectedConditions.isEmpty || !otherConditions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 7:
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dobString = dateFormatter.string(from: dob)
        
        let chronicConditionsString = Array(selectedConditions).joined(separator: ", ") + 
            (otherConditions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : ", " + otherConditions.trimmingCharacters(in: .whitespacesAndNewlines))
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            await viewModel.createUser(
                withEmail: trimmedEmail,
                password: trimmedPassword,
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                dob: dobString,
                gender: gender,
                phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                street: street.trimmingCharacters(in: .whitespacesAndNewlines),
                city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                state: state,
                zip: zip.trimmingCharacters(in: .whitespacesAndNewlines),
                insuranceProvider: insuranceProvider,
                insuranceMemberId: insuranceMemberId.trimmingCharacters(in: .whitespacesAndNewlines),
                allergies: allergies.trimmingCharacters(in: .whitespacesAndNewlines),
                chronicConditions: chronicConditionsString,
                heightFeet: heightFeet,
                heightInches: heightInches,
                weight: weight
            )
        }
    }
    
    private func clearForm() {
        firstName = ""
        lastName = ""
        dob = Date()
        gender = ""
        phoneNumber = ""
        street = ""
        city = ""
        state = ""
        zip = ""
        insuranceProvider = ""
        insuranceMemberId = ""
        allergies = ""
        heightFeet = ""
        heightInches = ""
        weight = ""
        selectedConditions.removeAll()
        otherConditions = ""
        email = ""
        password = ""
        confirmPassword = ""
        currentStep = 1
        viewModel.errorMessage = nil
        focusedField = nil
    }
    
    private func syncWithHealthKitForRegistration() {
        HealthKitManager.shared.requestAuthorization { success in
            guard success else { return }
            
            // Fetch characteristics
            do {
                let characteristics = try HealthKitManager.shared.fetchCharacteristics()
                if let dobFromHealth = characteristics.dateOfBirth {
                    self.dob = dobFromHealth
                }
                if let sexObject = characteristics.biologicalSex {
                    switch sexObject.biologicalSex {
                    case .female: self.gender = "Female"
                    case .male: self.gender = "Male"
                    case .other: self.gender = "Other"
                    default: self.gender = ""
                    }
                }
            } catch {
                print("Failed to fetch characteristics: \(error)")
            }
            
            // Fetch height and weight
            HealthKitManager.shared.fetchMostRecentHeight { heightInInches in
                if let height = heightInInches {
                    self.heightFeet = String(Int(height / 12))
                    self.heightInches = String(Int(height.truncatingRemainder(dividingBy: 12)))
                }
            }
            HealthKitManager.shared.fetchMostRecentWeight { weightInPounds in
                if let weight = weightInPounds {
                    self.weight = String(Int(weight.rounded()))
                }
            }
            
            
        }
    }
}
