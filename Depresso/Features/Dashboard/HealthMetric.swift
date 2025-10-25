// In Features/Dashboard/HealthMetric.swift
import Foundation
import SwiftUI

enum HealthMetricType: String, CaseIterable, Identifiable {
    case steps = "Steps"
    case calories = "Calories"
    case heartRate = "Heart Rate"
    
    var id: String { self.rawValue }
    
    var systemImageName: String {
        switch self {
        case .steps: return "figure.walk"
        case .calories: return "flame.fill"
        case .heartRate: return "heart.fill"
        }
    }
    
    var unit: String {
         switch self {
         case .steps: return ""
         case .calories: return "kcal"
         case .heartRate: return "bpm"
         }
     }
}

struct HealthMetric: Identifiable, Equatable {
    let id = UUID()
    let type: HealthMetricType
    let value: Double
    let date: Date
    
    var formattedValue: String {
        String(format: "%.0f", value)
    }
    
    static var mock: [HealthMetric] { /* ... keep mock data ... */
         [
             .init(type: .steps, value: Double.random(in: 3000...12000), date: .now),
             .init(type: .calories, value: Double.random(in: 150...600), date: .now),
             .init(type: .heartRate, value: Double.random(in: 60...90), date: .now)
         ]
     }
}

// ✅ Defined MetricCardView struct
struct MetricCardView: View {
    let metric: HealthMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: metric.type.systemImageName)
                    .foregroundStyle(Color.ds.accent)
                Text(metric.type.rawValue)
                    .font(.ds.caption)
                Spacer()
            }
            HStack(alignment: .lastTextBaseline) {
                 Text(metric.formattedValue)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                 Text(metric.type.unit)
                    .font(.ds.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
