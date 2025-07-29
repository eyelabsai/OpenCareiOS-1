# OpenCare iOS App

This iOS app is adapted from the OpenCare Web App to provide the same functionality on iOS devices. It features medical visit recording, medication management, health assistant, and comprehensive health tracking.

## Features

### 🏥 Medical Visit Management
- Record medical visits with audio transcription
- Automatic summarization using AI
- Visit history with filtering and search
- Detailed visit summaries with medications and actions

### 💊 Medication Management
- Track active and inactive medications
- Medication history and changes
- Automatic medication action detection from visits
- Medication scheduling and reminders

### 🤖 Health Assistant
- AI-powered health assistant
- Context-aware responses using visit and medication history
- Chat interface with message history
- Personalized health recommendations

### 📊 Health Dashboard
- Comprehensive health statistics
- Visit and medication analytics
- Health trends and insights
- Quick actions and recent activity

### 👤 User Profile
- Complete user profile management
- Medical history and conditions
- Insurance information
- Emergency contacts

## Architecture

The app follows the MVVM (Model-View-ViewModel) architecture pattern and is built using:

- **SwiftUI** for the user interface
- **Firebase** for backend services (Auth, Firestore)
- **Combine** for reactive programming
- **AVFoundation** for audio recording
- **OpenAI API** for transcription and summarization

## Data Models

### User
- Personal information (name, DOB, contact details)
- Medical information (allergies, conditions, insurance)
- Emergency contacts

### Visit
- Visit details (date, specialty, summary)
- Medications prescribed during visit
- Medication actions (start, stop, modify, continue)
- Chronic conditions discussed

### Medication
- Medication details (name, dosage, frequency)
- Instructions and timing
- Active/inactive status
- History and changes

### MedicationAction
- Action type (start, stop, modify, continue)
- Medication reference
- Reason and new instructions
- Visit association

## Setup Instructions

### Prerequisites
- Xcode 14.0 or later
- iOS 16.0 or later
- Firebase project with Firestore enabled
- OpenAI API key

### 1. Firebase Setup
1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Enable Authentication (Email/Password)
3. Enable Firestore Database
4. Download `GoogleService-Info.plist` and add to the project
5. Update Firebase configuration in `Config.swift`

### 2. OpenAI API Setup
1. Get an OpenAI API key from [OpenAI Platform](https://platform.openai.com)
2. Update the API key in your web app server
3. Ensure the web app server is running and accessible

### 3. Web App Server
1. Navigate to the `OpenCare_WebApp` directory
2. Install dependencies: `npm install`
3. Set up environment variables:
   ```
   OPENAI_API_KEY=your_openai_api_key
   ```
4. Start the server: `npm start`
5. Update the API base URL in `Config.swift` to match your server

### 4. Xcode Project Setup
1. Open `opencareai.xcodeproj` in Xcode
2. Update the Bundle Identifier to match your app
3. Configure signing and capabilities
4. Build and run the project

## API Integration

The app communicates with the web app server for:
- Audio transcription
- Visit summarization
- Health assistant queries

### API Endpoints
- `POST /api/transcribe` - Transcribe audio recordings
- `POST /api/summarise` - Summarize visit transcripts
- `POST /api/assistant` - Health assistant queries
- `GET /api/test` - Test server connection

## Firebase Collections

### users
- User profiles and medical information
- Authentication data

### visits
- Medical visit records
- Summaries and medications

### medications
- Medication records
- Active/inactive status

### visit_medications
- Medication actions during visits
- History tracking

### health_assistant_messages
- Health assistant conversation history
- User queries and responses

## Key Features Adapted from Web App

### 1. Dashboard Layout
- 2:1 grid layout matching web app design
- Stats cards with gradients
- Quick actions and recent activity
- Sidebar with active medications

### 2. Visit Recording
- Audio recording with transcription
- AI-powered summarization
- Automatic medication detection
- Visit history management

### 3. Medication Management
- Active/inactive medication tracking
- Medication history and changes
- Automatic action detection from visits
- Medication scheduling

### 4. Health Assistant
- Context-aware AI assistant
- Visit and medication history integration
- Chat interface with message history
- Personalized responses

### 5. Data Synchronization
- Real-time Firebase integration
- Offline capability with local caching
- Cross-device synchronization
- Data consistency with web app

## Development Notes

### File Structure
```
opencareai/
├── Models.swift              # Data models
├── FirebaseService.swift     # Firebase operations
├── APIService.swift          # Web API integration
├── ViewModels/               # MVVM view models
├── Views/                    # SwiftUI views
├── Components.swift          # Reusable UI components
├── Config.swift              # App configuration
└── README.md                 # This file
```

### Key Adaptations
1. **Data Models**: Updated to match web app structure
2. **Firebase Service**: Enhanced with web app functionality
3. **API Integration**: Direct integration with web app server
4. **UI Components**: Adapted web app design to iOS
5. **State Management**: Comprehensive app state management

### Performance Considerations
- Lazy loading for large datasets
- Image caching and optimization
- Background processing for audio
- Efficient Firebase queries

## Troubleshooting

### Common Issues
1. **Firebase Connection**: Ensure `GoogleService-Info.plist` is properly configured
2. **API Connection**: Verify web app server is running and accessible
3. **Audio Recording**: Check microphone permissions
4. **Data Sync**: Ensure Firebase rules allow read/write access

### Debug Mode
Enable debug logging by setting `DEBUG = true` in `Config.swift`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Check the troubleshooting section
- Review the web app documentation

---

**Note**: This iOS app is designed to work in conjunction with the OpenCare Web App. Ensure both applications are properly configured and the web app server is running for full functionality. 