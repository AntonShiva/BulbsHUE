//
//  MemoryDiagnosticsView.swift
//  BulbsHUE
//
//  Created by Claude Code on 04.09.2025.
//

import SwiftUI

/// View для отображения диагностики утечек памяти (только для DEBUG)
struct MemoryDiagnosticsView: View {
    @ObservedObject private var diagnostics = MemoryLeakDiagnosticsService.shared
    @State private var isExpanded = false
    @State private var showDetailedReport = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Заголовок с переключателем
            HStack {
                Button(action: { isExpanded.toggle() }) {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        Text("Memory Diagnostics")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Индикатор состояния
                        statusIndicator
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Toggle("", isOn: $diagnostics.isDiagnosticsEnabled)
                    .labelsHidden()
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Статистика по категориям
                    if !diagnostics.activeObjectsStats.isEmpty {
                        categoryStatsView
                    }
                    
                    // Предупреждения
                    if !diagnostics.memoryWarnings.isEmpty {
                        warningsView
                    }
                    
                    // Кнопки управления
                    controlButtonsView
                }
                .padding(.leading, 16)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showDetailedReport) {
            DetailedDiagnosticsView()
        }
    }
    
    // MARK: - Private Views
    
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(diagnosticsColor)
                .frame(width: 8, height: 8)
            
            Text("\(totalObjectCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var categoryStatsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Active Objects:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                ForEach(diagnostics.activeObjectsStats.sorted(by: { $0.key < $1.key }), id: \.key) { category, count in
                    HStack {
                        Text(category)
                            .font(.caption)
                        Spacer()
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
    
    private var warningsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Warnings:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.orange)
            
            ForEach(diagnostics.memoryWarnings.prefix(3)) { warning in
                HStack {
                    Text(warning.severity.emoji)
                    Text(warning.description)
                        .font(.caption)
                        .foregroundColor(warning.severity.color)
                    Spacer()
                }
            }
            
            if diagnostics.memoryWarnings.count > 3 {
                Text("... and \(diagnostics.memoryWarnings.count - 3) more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var controlButtonsView: some View {
        HStack(spacing: 8) {
            Button("Check Now") {
                diagnostics.performMemoryLeakCheck()
            }
            .font(.caption)
            
            Button("Detailed Report") {
                showDetailedReport = true
            }
            .font(.caption)
            
            if !diagnostics.memoryWarnings.isEmpty {
                Button("Clear Warnings") {
                    diagnostics.clearWarnings()
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalObjectCount: Int {
        diagnostics.activeObjectsStats.values.reduce(0, +)
    }
    
    private var diagnosticsColor: Color {
        if diagnostics.memoryWarnings.contains(where: { $0.severity == .critical }) {
            return .red
        } else if !diagnostics.memoryWarnings.isEmpty {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Detailed Diagnostics View

struct DetailedDiagnosticsView: View {
    @ObservedObject private var diagnostics = MemoryLeakDiagnosticsService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var report: DiagnosticsReport?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let report = report {
                        detailedReportView(report)
                    } else {
                        Text("Generating report...")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Memory Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                report = diagnostics.getDiagnosticsReport()
            }
        }
    }
    
    @ViewBuilder
    private func detailedReportView(_ report: DiagnosticsReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Общая статистика
            GroupBox("Overview") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Total Active Objects:")
                        Spacer()
                        Text("\(report.totalActiveObjects)")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Oldest Object Age:")
                        Spacer()
                        Text(formatTimeInterval(report.oldestObjectAge))
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Last Updated:")
                        Spacer()
                        Text(report.lastUpdated, format: .dateTime.hour().minute().second())
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Детальная статистика по категориям
            GroupBox("Category Breakdown") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(report.categoryBreakdown.sorted(by: { $0.key < $1.key }), id: \.key) { category, count in
                        HStack {
                            Text(category)
                            Spacer()
                            Text("\(count)")
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            // Предупреждения
            if !report.warnings.isEmpty {
                GroupBox("Warnings") {
                    ForEach(report.warnings) { warning in
                        HStack {
                            Text(warning.severity.emoji)
                            VStack(alignment: .leading) {
                                Text(warning.description)
                                    .font(.body)
                                Text(warning.timestamp, format: .dateTime.hour().minute().second())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Рекомендации
            GroupBox("Recommendations") {
                VStack(alignment: .leading, spacing: 8) {
                    if report.hasCriticalWarnings {
                        Label("Critical memory issues detected. Review object lifecycle management.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    } else if report.hasWarnings {
                        Label("Memory warnings detected. Monitor object counts.", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    } else {
                        Label("Memory usage looks healthy.", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? "0s"
    }
}

// MARK: - Debug Only

#if DEBUG
struct MemoryDiagnosticsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            MemoryDiagnosticsView()
            Spacer()
        }
        .padding()
        .environmentObject(MemoryLeakDiagnosticsService.createMock())
    }
}
#endif