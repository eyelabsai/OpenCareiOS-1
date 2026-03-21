# OpenCareAI iOS App

The **OpenCare web app** (API routes, summarization, medication verification, Firebase client parity) lives in a separate checkout:

`/Users/gurpalvirdi/OpenCare`

The **new visit** UI and client-side flow to keep in sync with iOS **Record New Visit** is:

`/Users/gurpalvirdi/OpenCare/public/new-visit.html`

Use that project for backend changes, local `npm` dev server, and Vercel deployment. It is not vendored inside this iOS repository.

The **`opencareai`** folder contains the Xcode / SwiftUI iOS app.

