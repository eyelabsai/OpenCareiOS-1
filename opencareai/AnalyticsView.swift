//
//  AnalyticsView.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/21/25.
//

import SwiftUI
import Charts

// A simple data structure for our charts
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

struct AnalyticsView: View {
    @EnvironmentObject var visitViewModel: VisitViewModel
    @EnvironmentObject var statsViewModel: StatsViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    
                    // Visits by Specialty Chart
                    visitsBySpecialtyChart
                    
                    // Monthly Visits Chart
                    monthlyVisitsChart
                    
                }
                .padding()
            }
            .navigationTitle("Health Analytics")
            .onAppear {
                // Ensure data is loaded
                Task {
                    await visitViewModel.loadVisitsAsync()
                    await statsViewModel.fetchStats()
                }
            }
        }
    }

    // MARK: - Visits by Specialty Chart
    private var visitsBySpecialtyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visits by Specialty")
                .font(.title2)
                .fontWeight(.semibold)
            
            if visitViewModel.visitsBySpecialty.isEmpty {
                Text("No visit data available to display charts.")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                Chart(visitsBySpecialtyData()) { dataPoint in
                    BarMark(
                        x: .value("Specialty", dataPoint.label),
                        y: .value("Number of Visits", dataPoint.value)
                    )
                    .foregroundStyle(by: .value("Specialty", dataPoint.label))
                }
                .chartLegend(.hidden)
                .frame(height: 250)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Monthly Visits Chart
    private var monthlyVisitsChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Visits (Last 12 Months)")
                .font(.title2)
                .fontWeight(.semibold)
            
            if monthlyVisitsData().isEmpty {
                Text("Not enough data for a monthly trend.")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                Chart(monthlyVisitsData()) { dataPoint in
                    LineMark(
                        x: .value("Month", dataPoint.label),
                        y: .value("Number of Visits", dataPoint.value)
                    )
                    PointMark(
                        x: .value("Month", dataPoint.label),
                        y: .value("Number of Visits", dataPoint.value)
                    )
                }
                .frame(height: 250)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Data Processing Helpers
    
    private func visitsBySpecialtyData() -> [ChartDataPoint] {
        return visitViewModel.visitsBySpecialty.map { (specialty, visits) in
            ChartDataPoint(label: specialty, value: Double(visits.count))
        }
        .sorted { $0.value > $1.value } // Sort to show most frequent first
    }
    
    private func monthlyVisitsData() -> [ChartDataPoint] {
        let calendar = Calendar.current
        let last12Months = (0..<12).map { i in
            calendar.date(byAdding: .month, value: -i, to: Date())!
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        
        // Group visits by month
        let visitsByMonth = Dictionary(grouping: visitViewModel.visits) { visit in
            let month = calendar.component(.month, from: visit.date ?? Date())
            let year = calendar.component(.year, from: visit.date ?? Date())
            return "\(year)-\(month)"
        }
        
        // Create data points for the last 12 months
        return last12Months.map { date in
            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date)
            let key = "\(year)-\(month)"
            let count = visitsByMonth[key]?.count ?? 0
            
            return ChartDataPoint(label: dateFormatter.string(from: date), value: Double(count))
        }.reversed() // Reverse to show chronologically
    }
}
