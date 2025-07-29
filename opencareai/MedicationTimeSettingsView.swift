//
//  MedicationTimeSettingsView.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/21/25.
//


import SwiftUI

struct MedicationTimeSettingsView: View {
    @StateObject private var userSettings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Medication Times"), footer: Text("Set your preferred times for medication reminders. These will be used for instructions like 'take in the morning' or 'take at bedtime'.")) {
                    DatePicker("Morning", selection: $userSettings.morningTime, displayedComponents: .hourAndMinute)
                    DatePicker("Afternoon", selection: $userSettings.afternoonTime, displayedComponents: .hourAndMinute)
                    DatePicker("Evening", selection: $userSettings.eveningTime, displayedComponents: .hourAndMinute)
                    DatePicker("Bedtime", selection: $userSettings.bedtimeTime, displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("Reminder Times")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}