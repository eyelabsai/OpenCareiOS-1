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
    
    @State private var showingAddCondition = false
    @State private var newCondition = ""
    
    private let genderOptions = ["", "Male", "Female", "Other", "Prefer not to say"]
    private let bloodTypeOptions = ["", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "Unknown"]
    private let insuranceOptions = ["", "Aetna", "Blue Cross", "Cigna", "UnitedHealthcare", "Kaiser", "None", "Other"]
    private let stateOptions = ["", "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    profileHeader
                    personalInfoSection
                    addressSection
                    insuranceSection
                    emergencySection
                    healthSection
                    healthKitSection
                    appearanceSection
                    reminderSettingsSection
                    chronicConditionsSection
                    accountActionsSection
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task { await viewModel.fetchUserProfile() }
            }
            .sheet(isPresented: $showingAddCondition) {
                AddConditionSheet(newCondition: $newCondition, onAdd: {
                    Task { await viewModel.addCondition(newCondition) }
                    newCondition = ""
                    showingAddCondition = false
                })
            }
            // --- This is the correct placement for the sheet modifier ---
        }
    }
    
    // MARK: - Subviews
    private var profileHeader: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 100, height: 100)
                .overlay(
                    Text((viewModel.user.firstName.prefix(1) + viewModel.user.lastName.prefix(1)).uppercased())
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                )
            VStack(spacing: 4) {
                Text(viewModel.user.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "User" : viewModel.user.fullName)
                    .font(.title2).fontWeight(.semibold)
                Text(viewModel.user.email).font(.subheadline).foregroundColor(.secondary)
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(16).shadow(radius: 2)
    }

    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Information").font(.headline).fontWeight(.semibold)
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "person.fill").foregroundColor(.blue).frame(width: 20)
                    TextField("First Name", text: $viewModel.user.firstName).textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Last Name", text: $viewModel.user.lastName).textFieldStyle(RoundedBorderTextFieldStyle())
                }
                HStack {
                    Image(systemName: "calendar").foregroundColor(.blue).frame(width: 20)
                    DatePicker("Date of Birth", selection: Binding(
                        get: { dateFromString(viewModel.user.dob) ?? Date() },
                        set: { viewModel.user.dob = stringFromDate($0) }
                    ), displayedComponents: .date).labelsHidden()
                }
                HStack {
                    Image(systemName: "person.2.fill").foregroundColor(.blue).frame(width: 20)
                    Picker("Gender", selection: $viewModel.user.gender) {
                        ForEach(genderOptions, id: \.self) { Text($0) }
                    }.pickerStyle(MenuPickerStyle())
                }
                HStack {
                    Image(systemName: "phone.fill").foregroundColor(.blue).frame(width: 20)
                    TextField("Phone Number", text: $viewModel.user.phoneNumber).textFieldStyle(RoundedBorderTextFieldStyle()).keyboardType(.phonePad)
                }
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(16).shadow(radius: 2)
    }

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Address").font(.headline).fontWeight(.semibold)
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
        }.padding().background(Color(.systemBackground)).cornerRadius(16).shadow(radius: 2)
    }
    
    private var insuranceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insurance").font(.headline).fontWeight(.semibold)
            VStack(spacing: 12) {
                Picker("Insurance Provider", selection: $viewModel.user.insuranceProvider) {
                    ForEach(insuranceOptions, id: \.self) { Text($0) }
                }.pickerStyle(MenuPickerStyle())
                TextField("Insurance Member ID", text: $viewModel.user.insuranceMemberId).textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(16).shadow(radius: 2)
    }
    
    private var emergencySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emergency Contact").font(.headline).fontWeight(.semibold)
            VStack(spacing: 12) {
                TextField("Contact Name", text: $viewModel.user.emergencyContactName).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Contact Phone", text: $viewModel.user.emergencyContactPhone).textFieldStyle(RoundedBorderTextFieldStyle()).keyboardType(.phonePad)
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(16).shadow(radius: 2)
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health").font(.headline).fontWeight(.semibold)
            VStack(spacing: 12) {
                TextField("Primary Physician", text: $viewModel.user.primaryPhysician).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Known Allergies", text: Binding(
                    get: { viewModel.user.allergies.joined(separator: ", ") },
                    set: { newValue in
                        viewModel.user.allergies = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    }
                )).textFieldStyle(RoundedBorderTextFieldStyle())
                HStack {
                    Text("Height:")
                    Picker("Feet", selection: $viewModel.user.heightFeet) {
                        ForEach((4...7).map { String($0) }, id: \.self) { Text("\($0) ft") }
                    }.pickerStyle(MenuPickerStyle())
                    Picker("Inches", selection: $viewModel.user.heightInches) {
                        ForEach((0...11).map { String($0) }, id: \.self) { Text("\($0) in") }
                    }.pickerStyle(MenuPickerStyle())
                }
                HStack {
                    Text("Weight:")
                    Picker("Weight", selection: $viewModel.user.weight) {
                        ForEach((80...400).map { String($0) }, id: \.self) { Text("\($0) lbs") }
                    }.pickerStyle(MenuPickerStyle())
                }
                Picker("Blood Type", selection: $viewModel.user.bloodType) {
                    ForEach(bloodTypeOptions, id: \.self) { Text($0) }
                }.pickerStyle(MenuPickerStyle())
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(16).shadow(radius: 2)
    }
    
    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Apple Health")
                .font(.headline)
                .fontWeight(.semibold)

            Button(action: syncWithHealthKit) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("Sync with Health App")
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Appearance").font(.headline).fontWeight(.semibold)
            VStack(spacing: 12) {
                Picker("Theme", selection: $appState.colorScheme) {
                    ForEach(ColorSchemeOption.allCases, id: \.self) { scheme in
                        Text(scheme.displayName).tag(scheme)
                    }
                }.pickerStyle(MenuPickerStyle())
                Text("Choose your preferred app appearance").font(.subheadline).foregroundColor(.secondary)
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(16).shadow(radius: 2)
    }
    
    private var reminderSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notification Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            NavigationLink(destination: MedicationTimeSettingsView()) {
                HStack {
                    Text("Medication Reminder Times")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var chronicConditionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Chronic Conditions").font(.headline).fontWeight(.semibold)
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
        }.padding().background(Color(.systemBackground)).cornerRadius(16).shadow(radius: 2)
    }

    private var accountActionsSection: some View {
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
        }.padding().background(Color(.systemBackground)).cornerRadius(16).shadow(radius: 2)
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

