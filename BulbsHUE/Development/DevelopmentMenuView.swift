//
//  DevelopmentMenuView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import SwiftUI

/// Development menu для разработчиков
struct DevelopmentMenuView: View {
    @EnvironmentObject private var navigationManager: NavigationManager
    @EnvironmentObject private var migrationAdapter: MigrationAdapter
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Заголовок
                    headerSection
                    
                    // Migration Section
                    migrationSection
                    
                    // Test Views Section
                    testViewsSection
                    
                    // Debug Information
                    debugInfoSection
                }
                .padding()
            }
            .navigationTitle("Development")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        navigationManager.go(.environment)
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .font(.largeTitle)
                .foregroundColor(.blue)
            
            Text("Development Tools")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Инструменты для разработки и отладки")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var migrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Clean Architecture Migration", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
                .foregroundColor(.blue)
            
            Text("Отслеживание прогресса миграции на Clean Architecture + Redux")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: {
                navigationManager.go(.migrationDashboard)
            }) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Migration Dashboard")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            
            // Feature Flags Status
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Feature Flags:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                FeatureFlagStatusRow(
                    title: "Bridge Architecture",
                    isEnabled: MigrationFeatureFlags.useNewBridgeArchitecture
                )
                
                FeatureFlagStatusRow(
                    title: "Redux Lights",
                    isEnabled: MigrationFeatureFlags.useReduxForLights
                )
                
                FeatureFlagStatusRow(
                    title: "Debug Mode",
                    isEnabled: MigrationFeatureFlags.debugMigration
                )
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var testViewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Test Views", systemImage: "testtube.2")
                .font(.headline)
                .foregroundColor(.orange)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                TestViewButton(
                    title: "Bridge Discovery",
                    icon: "wifi.router",
                    action: { /* TODO: Navigate to BridgeDiscoveryTestView */ }
                )
                
                TestViewButton(
                    title: "Onboarding",
                    icon: "person.badge.plus",
                    action: { /* TODO: Navigate to OnboardingTestView */ }
                )
                
                TestViewButton(
                    title: "Smart Discovery",
                    icon: "magnifyingglass.circle",
                    action: { /* TODO: Navigate to SmartDiscoveryTestView */ }
                )
                
                TestViewButton(
                    title: "Figma Preview",
                    icon: "photo.artframe",
                    action: { /* TODO: Navigate to FigmaPreview */ }
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var debugInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Debug Information", systemImage: "info.circle")
                .font(.headline)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Redux Store: ✅ Initialized")
                Text("Migration Adapter: ✅ Ready")
                Text("Navigation Manager: ✅ Active")
                
                if MigrationFeatureFlags.debugMigration {
                    Text("Debug Mode: ✅ Enabled")
                        .foregroundColor(.blue)
                } else {
                    Text("Debug Mode: ❌ Disabled")
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FeatureFlagStatusRow: View {
    let title: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Text("• \(title)")
                .font(.caption)
            Spacer()
            Text(isEnabled ? "ON" : "OFF")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isEnabled ? .green : .red)
        }
    }
}

struct TestViewButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

#if DEBUG
struct DevelopmentMenuView_Previews: PreviewProvider {
    static var previews: some View {
        DevelopmentMenuView()
            .environmentObject(NavigationManager.shared)
            .environmentObject(MigrationAdapter(
                store: AppStore(),
                appViewModel: AppViewModel()
            ))
    }
}
#endif
