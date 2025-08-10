//
//  ProfileView.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/3/25.
//

import SwiftUI
import UIKit // Keep this import for the DocumentExporter

struct ProfileView: View {
    @StateObject private var viewModel = UserViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var appState: AppState
    
    // EnvironmentObjects for the report
    @EnvironmentObject var visitViewModel: VisitViewModel
    @EnvironmentObject var medicationViewModel: MedicationViewModel
    
    @State private var reportURL: URL?
    @State private var selectedTab = 0
    
    @State private var showingAddCondition = false
    @State private var newCondition = ""
    
    @State private var showingDeleteAccountConfirmation = false
    @State private var deleteAccountPassword = ""
    @State private var showingHealthKitExplanation = false
    @State private var healthKitSyncType: HealthKitSyncType = .basicData

    private let genderOptions = ["", "Male", "Female", "Other", "Prefer not to say"]
    private let bloodTypeOptions = ["", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "Unknown"]
    private let insuranceOptions = ["", "Aetna", "Blue Cross", "Cigna", "UnitedHealthcare", "Kaiser", "None", "Other"]
    private let stateOptions = ["", "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Profile Header
                profileHeader
                    .padding(.horizontal)
                    .padding(.top)
                
                // Custom Tab Picker
                HStack(spacing: 0) {
                    ForEach(0..<3) { index in
                        Button(action: { selectedTab = index }) {
                            Text(tabTitle(for: index))
                                .font(.system(size: 15, weight: selectedTab == index ? .semibold : .medium))
                                .foregroundColor(selectedTab == index ? .white : .primary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    selectedTab == index ? 
                                        Color.blue : 
                                        Color.clear
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if index < 2 {
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    // Profile Tab
                    ScrollView {
                        VStack(spacing: 20) {
                            if let errorMessage = viewModel.errorMessage {
                                if viewModel.showingProfileRecovery {
                                    // Profile Recovery Interface
                                    VStack(spacing: 20) {
                                        VStack(spacing: 12) {
                                            Image(systemName: "person.crop.circle.badge.plus")
                                                .font(.system(size: 50))
                                                .foregroundColor(.blue)
                                            
                                            Text("Complete Your Profile")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                            
                                            Text(errorMessage)
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(12)
                                        
                                        // Show the profile form for completion
                                        VStack(spacing: 20) {
                                            personalInfoSection
                                            addressSection
                                            insuranceSection
                                        }
                                        
                                        Button(action: {
                                            Task {
                                                await viewModel.createMissingProfile()
                                            }
                                        }) {
                                            HStack {
                                                if viewModel.isLoading {
                                                    ProgressView()
                                                        .scaleEffect(0.8)
                                                        .foregroundColor(.white)
                                                } else {
                                                    Image(systemName: "checkmark.circle.fill")
                                                }
                                                Text("Save Profile")
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                            .fontWeight(.semibold)
                                        }
                                        .disabled(viewModel.isLoading)
                                    }
                                } else {
                                    // Regular error display
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                        .padding()
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            } else if !viewModel.showingProfileRecovery {
                                // Normal profile content when no errors and not in recovery mode
                                personalInfoSection
                                addressSection
                                insuranceSection
                            }
                        }
                        .padding()
                    }
                    .tag(0)
                    
                    // Health Tab
                    ScrollView {
                        VStack(spacing: 20) {
                            healthSection
                            healthKitSection
                            chronicConditionsSection
                        }
                        .padding()
                    }
                    .tag(1)
                    
                    // Settings Tab
                    ScrollView {
                        VStack(spacing: 20) {
                            appearanceSection
                            reminderSettingsSection
                            accountActionsSection
                        }
                        .padding()
                    }
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task { await viewModel.fetchUserProfile() }
            }
            .sheet(isPresented: $showingHealthKitExplanation) {
                HealthKitExplanationView(
                    syncType: healthKitSyncType,
                    onProceed: {
                        showingHealthKitExplanation = false
                        switch healthKitSyncType {
                        case .basicData:
                            UserDefaults.standard.set(true, forKey: "hasShownHealthKitBasicExplanation")
                            syncWithHealthKit()
                        case .medications:
                            UserDefaults.standard.set(true, forKey: "hasShownHealthKitMedicationExplanation")
                            syncMedicationsWithHealthKit()
                        }
                    },
                    onCancel: {
                        showingHealthKitExplanation = false
                    }
                )
            }
            .sheet(isPresented: $showingAddCondition) {
                AddConditionSheet(newCondition: $newCondition, onAdd: {
                    Task { await viewModel.addCondition(newCondition) }
                    newCondition = ""
                    showingAddCondition = false
                })
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Subviews
    private var profileHeader: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 60, height: 60)
                .overlay(
                    Text((viewModel.user.firstName.prefix(1) + viewModel.user.lastName.prefix(1)).uppercased())
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.user.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "User" : viewModel.user.fullName)
                    .font(.title3).fontWeight(.semibold)
                Text(viewModel.user.email).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }

    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Personal Information")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "person.fill").foregroundColor(.blue).frame(width: 20)
                    TextField("First Name", text: $viewModel.user.firstName).textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Last Name", text: $viewModel.user.lastName).textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                if !viewModel.user.firstName.isEmpty || !viewModel.user.lastName.isEmpty {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption2)
                        Text("Name can be synced from Apple Health")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "calendar").foregroundColor(.blue).frame(width: 20)
                        DatePicker("Date of Birth", selection: Binding(
                            get: { dateFromString(viewModel.user.dob) ?? Date() },
                            set: { viewModel.user.dob = stringFromDate($0) }
                        ), displayedComponents: .date).labelsHidden()
                    }
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption2)
                        Text("Date of birth from Apple Health")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "person.2.fill").foregroundColor(.blue).frame(width: 20)
                        Picker("Gender", selection: $viewModel.user.gender) {
                            ForEach(genderOptions, id: \.self) { Text($0) }
                        }.pickerStyle(MenuPickerStyle())
                    }
                    if !viewModel.user.gender.isEmpty {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                            Text("Biological sex from Apple Health")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                HStack {
                    Image(systemName: "phone.fill").foregroundColor(.blue).frame(width: 20)
                    TextField("Phone Number", text: $viewModel.user.phoneNumber).textFieldStyle(RoundedBorderTextFieldStyle()).keyboardType(.phonePad)
                }
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(12).shadow(radius: 1)
    }

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "house.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Address")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            VStack(spacing: 12) {
                TextField("Street Address", text: $viewModel.user.street).textFieldStyle(RoundedBorderTextFieldStyle())
                HStack {
                    TextField("City", text: $viewModel.user.city).textFieldStyle(RoundedBorderTextFieldStyle())
                    Picker("State", selection: $viewModel.user.state) {
                        ForEach(stateOptions, id: \.self) { Text($0) }
                    }.pickerStyle(MenuPickerStyle())
                    TextField("ZIP", text: $viewModel.user.zip).textFieldStyle(RoundedBorderTextFieldStyle()).keyboardType(.numbersAndPunctuation)
                }
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(12).shadow(radius: 1)
    }
    
    private var insuranceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "creditcard.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Insurance")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            VStack(spacing: 12) {
                Picker("Insurance Provider", selection: $viewModel.user.insuranceProvider) {
                    ForEach(insuranceOptions, id: \.self) { Text($0) }
                }.pickerStyle(MenuPickerStyle())
                TextField("Insurance Member ID", text: $viewModel.user.insuranceMemberId).textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(12).shadow(radius: 1)
    }
    


    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .foregroundColor(.pink)
                    .font(.title2)
                Text("Health Information")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            VStack(spacing: 12) {
                TextField("Primary Physician", text: $viewModel.user.primaryPhysician).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Known Allergies", text: Binding(
                    get: { viewModel.user.allergies.joined(separator: ", ") },
                    set: { newValue in
                        viewModel.user.allergies = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    }
                )).textFieldStyle(RoundedBorderTextFieldStyle())
                VStack(spacing: 4) {
                    HStack {
                        Text("Height:")
                        Picker("Feet", selection: $viewModel.user.heightFeet) {
                            ForEach((4...7).map { String($0) }, id: \.self) { Text("\($0) ft") }
                        }.pickerStyle(MenuPickerStyle())
                        Picker("Inches", selection: $viewModel.user.heightInches) {
                            ForEach((0...11).map { String($0) }, id: \.self) { Text("\($0) in") }
                        }.pickerStyle(MenuPickerStyle())
                    }
                    if !viewModel.user.heightFeet.isEmpty && !viewModel.user.heightInches.isEmpty {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                            Text("Height synced from Apple Health")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                VStack(spacing: 4) {
                    HStack {
                        Text("Weight:")
                        Picker("Weight", selection: $viewModel.user.weight) {
                            ForEach((80...400).map { String($0) }, id: \.self) { Text("\($0) lbs") }
                        }.pickerStyle(MenuPickerStyle())
                    }
                    if !viewModel.user.weight.isEmpty {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                            Text("Weight synced from Apple Health")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                Picker("Blood Type", selection: $viewModel.user.bloodType) {
                    ForEach(bloodTypeOptions, id: \.self) { Text($0) }
                }.pickerStyle(MenuPickerStyle())
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(12).shadow(radius: 1)
    }
    
    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.text.square.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                Text("Apple Health Integration")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("This app uses HealthKit to:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Read your height, weight, and basic health data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Sync medication information with Health app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Access your date of birth and biological sex")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)
            }

            VStack(spacing: 12) {
                Button(action: { 
                    if UserDefaults.standard.bool(forKey: "hasShownHealthKitBasicExplanation") {
                        syncWithHealthKit()
                    } else {
                        healthKitSyncType = .basicData
                        showingHealthKitExplanation = true
                    }
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Sync Basic Health Data")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Image(systemName: "applelogo")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            Text("Imports height, weight, and characteristics from HealthKit")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { 
                    if UserDefaults.standard.bool(forKey: "hasShownHealthKitMedicationExplanation") {
                        syncMedicationsWithHealthKit()
                    } else {
                        healthKitSyncType = .medications
                        showingHealthKitExplanation = true
                    }
                }) {
                    HStack {
                        Image(systemName: "pills.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Sync Medications")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Image(systemName: "applelogo")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            Text("Two-way sync with Health app medication records")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "paintbrush.circle.fill")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("Appearance")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            VStack(spacing: 12) {
                Picker("Theme", selection: $appState.colorScheme) {
                    ForEach(ColorSchemeOption.allCases, id: \.self) { scheme in
                        Text(scheme.displayName).tag(scheme)
                    }
                }.pickerStyle(MenuPickerStyle())
                Text("Choose your preferred app appearance").font(.subheadline).foregroundColor(.secondary)
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(12).shadow(radius: 1)
    }
    
    private var reminderSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Notification Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            NavigationLink(destination: MedicationTimeSettingsView()) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("Medication Reminder Times")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }

    private var chronicConditionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.text.square.circle.fill")
                    .foregroundColor(.pink)
                    .font(.title2)
                Text("Chronic Conditions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showingAddCondition = true }) {
                    Image(systemName: "plus.circle.fill").foregroundColor(.blue).font(.title2)
                }
            }
            if viewModel.user.chronicConditions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square").font(.system(size: 40)).foregroundColor(.gray)
                    Text("No chronic conditions added").font(.subheadline).foregroundColor(.secondary)
                    Button("Add Condition") { showingAddCondition = true }.buttonStyle(.bordered)
                }.padding().frame(maxWidth: .infinity).background(Color(.systemGray6)).cornerRadius(12)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(viewModel.user.chronicConditions, id: \.self) { condition in
                        HStack {
                            Text(condition).font(.subheadline).lineLimit(1)
                            Spacer()
                            Button(action: { Task { await viewModel.removeCondition(condition) } }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red).font(.caption)
                            }
                        }.padding(.horizontal, 12).padding(.vertical, 8).background(Color.blue.opacity(0.1)).cornerRadius(8)
                    }
                }
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(12).shadow(radius: 1)
    }

    private var accountActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gear.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title2)
                Text("Account Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                Button(action: generateAndExportReport) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Export Health Report")
                    }.frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
                }
                Button(action: { Task { await viewModel.updateUserProfile() } }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save Changes")
                    }.frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(12)
                }.disabled(viewModel.isLoading)
                Button(action: { authViewModel.signOut() }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }.frame(maxWidth: .infinity).padding().background(Color.red).foregroundColor(.white).cornerRadius(12)
                }
                Button(action: { showingDeleteAccountConfirmation = true }) {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "trash.fill")
                        }
                        Text("Delete Account")
                    }.frame(maxWidth: .infinity).padding().background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(12)
                }
                .disabled(authViewModel.isLoading)
                
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(12).shadow(radius: 1)
        .sheet(isPresented: $showingDeleteAccountConfirmation) {
            DeleteAccountConfirmationView(
                password: $deleteAccountPassword,
                authViewModel: authViewModel,
                isPresented: $showingDeleteAccountConfirmation
            )
        }
        .onAppear {
            // Clear any previous error messages when profile view appears
            authViewModel.errorMessage = nil
        }
    }
    
    // MARK: - Helper Functions
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Profile"
        case 1: return "Health"
        case 2: return "Settings"
        default: return ""
        }
    }
    
    // MARK: - Functions
    
    private func syncWithHealthKit() {
        HealthKitManager.shared.requestAuthorization { success in
            guard success else { return }
            
            // Fetch Height
            HealthKitManager.shared.fetchMostRecentHeight { heightInInches in
                if let height = heightInInches {
                    let feet = Int(height / 12)
                    let inches = Int(height.truncatingRemainder(dividingBy: 12))
                    viewModel.user.heightFeet = String(feet)
                    viewModel.user.heightInches = String(inches)
                }
            }
            
            // Fetch Weight
            HealthKitManager.shared.fetchMostRecentWeight { weightInPounds in
                if let weight = weightInPounds {
                    viewModel.user.weight = String(Int(weight.rounded()))
                }
            }
            
        }
    }
    
    private func syncMedicationsWithHealthKit() {
        HealthKitManager.shared.requestAuthorization { success in
            guard success else { 
                print("HealthKit authorization denied")
                return 
            }
            
            // Get current medications from the app
            let currentMedications = self.medicationViewModel.medications
            
            HealthKitManager.shared.performTwoWayMedicationSync(appMedications: currentMedications) { syncResult in
                print("🔄 Medication Sync Complete:")
                print(syncResult.summary)
                
                // Show matched medications
                print("\n✅ Matched Medications:")
                for match in syncResult.matchedMedications {
                    let matchTypeStr = match.matchType == .nameAndDosage ? "exact" : "name only"
                    print("- \(match.appMedication.name) (\(matchTypeStr) match) - \(match.healthKitRecords.count) HealthKit records")
                }
                
                // Show new medications found in HealthKit
                if !syncResult.unmatchedHealthKitRecords.isEmpty {
                    print("\n🆕 New Medications from HealthKit:")
                    let groupedRecords = Dictionary(grouping: syncResult.unmatchedHealthKitRecords) { $0.name }
                    for (name, records) in groupedRecords {
                        print("- \(name): \(records.count) doses recorded")
                    }
                }
                
                // Show medications written to HealthKit
                if !syncResult.medicationsToWriteToHealthKit.isEmpty {
                    let status = syncResult.healthKitWriteSuccess ? "✅ Success" : "❌ Failed"
                    print("\n📤 Written to HealthKit (\(status)):")
                    for medication in syncResult.medicationsToWriteToHealthKit {
                        print("- \(medication.name) (\(medication.dosage))")
                    }
                    
                    if syncResult.healthKitWriteSuccess {
                        print("\n🔍 To see your medications in Health app:")
                        print("   1. Open Health app")
                        print("   2. Tap 'Browse' tab")
                        print("   3. Scroll to 'Other Data'")
                        print("   4. Tap 'Handwashing'")
                        print("   5. Your medications will appear as handwashing events with medication names in the details")
                    }
                }
                
                // Future: Could show UI dialog for user to review and approve new medications
            }
        }
    }
    
    private func generateAndExportReport() {
            // 1. Create the report view
            let reportView = HealthReportView(
                userViewModel: self.viewModel,
                visitViewModel: self.visitViewModel,
                medicationViewModel: self.medicationViewModel
            )
            
            // 2. Generate the PDF and get its URL
            guard let url = PDFGenerator.generate(from: reportView) else {
                print("Failed to generate PDF URL.")
                return
            }
            self.reportURL = url
            
            // 3. Present the document picker using UIKit
            guard let rootViewController = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?
                .windows
                .first?
                .rootViewController else {
                print("Could not find root view controller.")
                return
            }
            
            let documentPicker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
            
            // We don't need a delegate for this simple save operation
            
            rootViewController.present(documentPicker, animated: true, completion: nil)
        }
    
    private func dateFromString(_ str: String) -> Date? {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; return formatter.date(from: str)
    }
    
    private func stringFromDate(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; return formatter.string(from: date)
    }
} // --- THIS IS THE CORRECT CLOSING BRACE FOR THE ProfileView STRUCT ---

// MARK: - Helper Enums
enum HealthKitSyncType {
    case basicData
    case medications
}

// MARK: - Helper Structs
struct AddConditionSheet: View {
    @Binding var newCondition: String
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let commonConditions = ["Hypertension", "Diabetes", "Asthma"]
    
    var body: some View {
        NavigationView {
            VStack {
                // UI for adding a condition
                Text("Add a new condition").font(.headline)
                TextField("Condition name", text: $newCondition).textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                    Button("Add") { onAdd() }.buttonStyle(.borderedProminent).disabled(newCondition.isEmpty)
                }
            }.padding()
        }
    }
}

// MARK: - HealthKit Explanation View
struct HealthKitExplanationView: View {
    let syncType: HealthKitSyncType
    let onProceed: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.red, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Apple Health Integration")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.top, 20)
                
                // Content based on sync type
                VStack(alignment: .leading, spacing: 16) {
                    if syncType == .basicData {
                        Text("This will sync your basic health data:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Height and weight measurements")
                            }
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Date of birth and biological sex")
                            }
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Most recent values from Health app")
                            }
                        }
                        .font(.subheadline)
                        
                    } else {
                        Text("This will sync your medications:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Import medication records from Health app")
                            }
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Export your app medications to Health app")
                            }
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Two-way synchronization")
                            }
                        }
                        .font(.subheadline)
                    }
                    
                    // Access instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To view synced data in Apple Health:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Open the Health app")
                            Text("2. Tap 'Browse' at the bottom")
                            if syncType == .basicData {
                                Text("3. Find 'Body Measurements' for height/weight")
                                Text("4. Or go to 'Health Details' for personal info")
                            } else {
                                Text("3. Scroll to 'Other Data'")
                                Text("4. Look for 'Mindfulness' (medications stored here)")
                                Text("5. Check metadata for medication details")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    Button(action: onProceed) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.white)
                            Text("Continue with Sync")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: onCancel) {
                        Text("Not Now")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
}

