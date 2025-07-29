//
//  VisitRowView.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/21/25.
//

import SwiftUI

// MARK: - Visit Row View
struct VisitRowView: View {
    let visit: Visit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(visit.specialty ?? "Unknown")
                .font(.subheadline).fontWeight(.semibold)
            
            Text(visit.formattedDate)
                .font(.caption).foregroundColor(.secondary)
            
            if let tldr = visit.tldr, !tldr.isEmpty {
                Text(tldr)
                    .font(.caption).foregroundColor(.secondary).lineLimit(2)
            }
        }
    }
}
