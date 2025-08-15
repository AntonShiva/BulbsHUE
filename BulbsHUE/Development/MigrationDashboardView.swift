//
//  MigrationDashboardView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.            ForEach(MigrationStep.allCases) { step in//

import SwiftUI

/// Dashboard для отслеживания прогресса миграции (только для разработки)
struct MigrationDashboardView: View {
    @StateObject private var status = MigrationStatus()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Общий прогресс
                    progressSection
                    
                    // Feature Flags
                    featureFlagsSection
                    
                    // Этапы миграции
                    stepsSection
                }
                .padding()
            }
            .navigationTitle("Migration Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            Text("Общий прогресс миграции")
                .font(.headline)
            
            ProgressView(value: status.progress) {
                Text("\(Int(status.progress * 100))% завершено")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .progressViewStyle(LinearProgressViewStyle())
            
            Text("Текущий этап: \(status.currentStep.title)")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var featureFlagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Feature Flags")
                .font(.headline)
            
            FeatureFlagRow(
                title: "Bridge Architecture",
                isEnabled: MigrationFeatureFlags.useNewBridgeArchitecture
            )
            
            FeatureFlagRow(
                title: "Redux Lights",
                isEnabled: MigrationFeatureFlags.useReduxForLights
            )
            
            FeatureFlagRow(
                title: "Redux Scenes",
                isEnabled: MigrationFeatureFlags.useReduxForScenes
            )
            
            FeatureFlagRow(
                title: "Redux Groups",
                isEnabled: MigrationFeatureFlags.useReduxForGroups
            )
            
            FeatureFlagRow(
                title: "Debug Mode",
                isEnabled: MigrationFeatureFlags.debugMigration
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Этапы миграции")
                .font(.headline)
            
            ForEach(MigrationStep.allCases) { step in
                MigrationStepCard(
                    step: step,
                    isCompleted: status.isCompleted(step),
                    isCurrent: status.currentStep == step
                ) {
                    status.markCompleted(step)
                }
            }
        }
    }
}

struct FeatureFlagRow: View {
    let title: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(.body, design: .monospaced))
            
            Spacer()
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isEnabled ? .green : .red)
        }
        .padding(.vertical, 2)
    }
}

struct MigrationStepCard: View {
    let step: MigrationStep
    let isCompleted: Bool
    let isCurrent: Bool
    let onMarkCompleted: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Заголовок
            HStack {
                stepIcon
                
                VStack(alignment: .leading) {
                    Text(step.title)
                        .font(.headline)
                        .foregroundColor(isCurrent ? .blue : .primary)
                    
                    if isCurrent {
                        Text("ТЕКУЩИЙ ЭТАП")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            
            // Развернутая информация
            if isExpanded {
                Divider()
                
                Text(step.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if !step.risks.isEmpty {
                    Text("⚠️ Риски:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    ForEach(step.risks, id: \.self) { risk in
                        Text("• \(risk)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if !step.successCriteria.isEmpty {
                    Text("✅ Критерии успеха:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    ForEach(step.successCriteria, id: \.self) { criteria in
                        Text("• \(criteria)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                if isCurrent && !isCompleted {
                    Button("Отметить как выполненный") {
                        onMarkCompleted()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .stroke(borderColor, lineWidth: isCurrent ? 2 : 1)
        )
        .onTapGesture {
            isExpanded.toggle()
        }
    }
    
    private var stepIcon: some View {
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
            .foregroundColor(isCompleted ? .green : (isCurrent ? .blue : .gray))
            .font(.title2)
    }
    
    private var backgroundColor: Color {
        if isCompleted {
            return Color.green.opacity(0.1)
        } else if isCurrent {
            return Color.blue.opacity(0.1)
        } else {
            return Color(.systemGray6)
        }
    }
    
    private var borderColor: Color {
        if isCompleted {
            return .green
        } else if isCurrent {
            return .blue
        } else {
            return .clear
        }
    }
}

#if DEBUG
struct MigrationDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        MigrationDashboardView()
    }
}
#endif
