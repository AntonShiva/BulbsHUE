//
//  DevelopmentMenuView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import SwiftUI

/// Simplified Development menu
struct DevelopmentMenuView: View {
    @Environment(NavigationManager.self) private var navigationManager
    @Environment(AppViewModel.self) private var appViewModel
    
    @State private var diagnosticResult: String = ""
    @State private var showDiagnosticSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    testViewsSection
                    diagnosticsSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Development")
            .sheet(isPresented: $showDiagnosticSheet) {
                diagnosticSheet
            }
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("🛠 Development Tools")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Debugging and testing utilities")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var testViewsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("🎯 Test Views")
                .font(.headline)
            
            Button("Back to Environment") {
                navigationManager.go(.environment)
            }
            .padding()
            .background(Color.green.opacity(0.2))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("🔍 Diagnostics")
                .font(.headline)
            
            Button("Run Memory Diagnostics") {
                runMemoryDiagnostics()
            }
            .padding()
            .background(Color.orange.opacity(0.2))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var diagnosticSheet: some View {
        NavigationView {
            ScrollView {
                Text(diagnosticResult)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Diagnostic Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showDiagnosticSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func runMemoryDiagnostics() {
        diagnosticResult = """
        📊 Basic Memory Diagnostics
        
        ✅ App State: Active
        📱 Lights Count: \(appViewModel.lightsViewModel.lights.count)
        🔌 Connection: \(appViewModel.connectionStatus)
        
        📈 System Info:
        - Current route: \(navigationManager.currentRoute)
        - Tab visible: \(navigationManager.isTabBarVisible)
        
        🎯 Architecture: Clean Architecture with @Observable
        """
        
        showDiagnosticSheet = true
    }
}

#Preview {
    DevelopmentMenuView()
        .environment(NavigationManager.shared)
        .environment(AppViewModel())
}