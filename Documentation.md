# OpenCare iOS App - Clinical Health Records API Integration Documentation

This document provides detailed information about how the OpenCare iOS application integrates with Apple's Clinical Health Records API, as required by Apple App Store Review Guideline 2.1.

## App Overview

**App Name:** OpenCare  
**Bundle ID:** ai.opencare.app  
**Version:** 1.0.1  
**Purpose:** A healthcare application that helps users manage their medications, visit preparations, and health records with AI assistance.

## Clinical Health Records API Integration Details

### 1. How the App Integrates with Clinical Health Records API

The OpenCare app integrates with Apple's Clinical Health Records API through the following mechanisms:

**Primary Integration Points:**
- **File:** `HealthKitManager.swift:25` - Requests access to `HKClinicalType(.medicationRecord)`
- **File:** `HealthKitManager.swift:111-182` - Core function `fetchClinicalMedicationRecords()` that queries clinical medication data
- **File:** `HealthKitManager.swift:114-115` - Uses FHIR resource type `.medicationStatement` for clinical records

**Technical Implementation:**
```swift
// Request clinical medication record access
types.insert(HKClinicalType(.medicationRecord))

// Query clinical records with FHIR predicate  
let predicate = HKQuery.predicateForClinicalRecords(withFHIRResourceType: .medicationStatement)
```

**Data Processing:**
- The app parses FHIR (Fast Healthcare Interoperability Resources) data from healthcare providers
- Extracts medication names from FHIR fields: `medicationCodeableConcept` and `medicationReference`
- Extracts dosage information from `dosageInstruction` FHIR field
- Converts clinical data into app's medication format for user management

### 2. Where User Information is Uploaded and Frequency

**Data Upload Destination:**
- **Primary Server:** `https://opencare-gpt.vercel.app` (as specified in Info.plist:44)
- **Firebase Backend:** User data is stored in Firebase Firestore collections
- **Collections Used:** 
  - `health_assistant_messages` - Health-related conversations
  - User medication data through `OpenCareFirebaseService`

**Upload Frequency:**
- **Real-time:** Health assistant messages are uploaded immediately when users interact with the AI
- **On-demand:** Medication data synced when user explicitly triggers Apple Health sync
- **Event-based:** Data uploaded when users add/modify medications or visit information
- **No automatic background uploads** - All data uploads require explicit user action

**What Data is Uploaded:**
- Processed medication information (names, dosages, instructions) - NOT raw clinical records
- User-entered health conversation history
- Visit preparation data and medication management information
- NO raw FHIR data or clinical records are uploaded to external servers

### 3. Features Requiring User Information

**Features that Access Clinical Health Records:**

1. **Medication Sync Feature** (`HealthKitManager.swift:296-348`)
   - **Purpose:** Syncs medications from Apple Health clinical records to the app
   - **How Enabled:** User must grant HealthKit clinical records permission
   - **How to Disable:** 
     - iOS Settings → Privacy & Security → Health → Data Access & Devices → OpenCare → Turn off "Clinical Health Records"
     - Or deny permission when initially prompted

2. **Apple Health Integration** (`MedicationViewModel.swift:399-429`)
   - **Purpose:** Two-way sync between app medications and Apple Health
   - **How Enabled:** User taps "Sync with Apple Health" button in medication view
   - **How to Disable:** 
     - Revoke HealthKit permissions in iOS Settings
     - Feature becomes inaccessible without permission

3. **Medication Management** (`HealthKitManager.swift:97-109`)
   - **Purpose:** Fetches clinical medication records to pre-populate user's medication list
   - **How Enabled:** Automatic when clinical records permission granted
   - **How to Disable:** Revoke clinical health records access in iOS Settings

**Features NOT Requiring Clinical Records:**
- Basic medication tracking and reminders
- Health assistant conversations
- Visit preparation tools
- Manual medication entry

### 4. Additional Data Usage Information

**HealthKit Permissions Requested:**
- `NSHealthShareUsageDescription`: Read height, weight, date of birth, biological sex, and medication records
- `NSHealthUpdateUsageDescription`: Write medication tracking data to HealthKit
- `NSHealthRecordsUsageDescription`: Access health records including medication information
- `NSHealthClinicalHealthRecordsShareUsageDescription`: Access clinical health records from healthcare providers

**Data Security Measures:**
- All clinical data processing happens locally on device
- Only processed, non-clinical medication information is uploaded to servers
- Raw FHIR clinical records never leave the device
- User authentication required through Firebase Auth for all data access
- HTTPS encryption for all network communications

**User Control:**
- Users can revoke clinical records access at any time through iOS Settings
- Medication sync is entirely optional and user-initiated
- App functions without clinical records access (users can manually enter medications)
- Clear permission prompts explain data usage before access

**Data Retention:**
- Clinical records are never stored on external servers
- Only processed medication names/dosages stored in user's personal Firebase account
- Users can delete their account and all associated data at any time

### 5. Compliance with Healthcare Regulations

**FHIR Compliance:**
- App properly parses FHIR R4 medication statement resources
- Follows HL7 FHIR standards for clinical data interpretation
- Respects clinical data structure and terminology

**Privacy Protection:**
- Clinical records processing is local-only
- No protected health information (PHI) uploaded to external servers
- User consent required before any clinical data access
- Transparent data usage descriptions in all permission prompts

## Technical Architecture Summary

The OpenCare app uses Apple's Clinical Health Records API solely to enhance user experience by:
1. Pre-populating medication lists from clinical sources
2. Reducing manual data entry for users
3. Ensuring medication information accuracy from healthcare providers
4. Enabling optional synchronization between clinical records and user's medication management

All clinical data remains on the user's device, with only processed, non-clinical medication management information shared with the app's backend services for personalized health assistance features.