//
//  BridgeStatusView.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI

/// View для отображения статуса подключения и информации о Hue Bridge
struct BridgeStatusView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingDisconnectAlert = false
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Фоновый градиент
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.15),
                        Color(red: 0.05, green: 0.05, blue: 0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Заголовок
                        headerView
                            .padding(.top, 20)
                        
                        // Статус подключения
                        statusCard
                            .padding(.top, 30)
                        
                        // Информация о мосте
                        if viewModel.connectionStatus == .connected,
                           let bridge = viewModel.currentBridge {
                            bridgeInfoCard(bridge: bridge)
                                .padding(.top, 20)
                            
                            // Статистика
                            statisticsCard
                                .padding(.top, 20)
                            
                            // Действия
                            actionsCard
                                .padding(.top, 20)
                        } else if viewModel.connectionStatus == .disconnected {
                            // Кнопка для настройки нового подключения
                            Button(action: {
                                viewModel.showSetup = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    Text("Добавить мост")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.top, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Отключить мост?", isPresented: $showingDisconnectAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Отключить", role: .destructive) {
                viewModel.disconnectAndClearData()
            }
        } message: {
            Text("Все сохраненные данные подключения будут удалены")
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 50))
                .foregroundColor(.white)
                .symbolRenderingMode(.hierarchical)
            
            Text("Hue Bridge")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        VStack(spacing: 20) {
            HStack {
                Text("СВЕДЕНИЯ")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                Spacer()
            }
            
            // Статус
            HStack {
                Text("Статус")
                    .font(.body)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(statusText)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                }
            }
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Bridge Info Card
    
    private func bridgeInfoCard(bridge: Bridge) -> some View {
        VStack(spacing: 16) {
            // Идентификатор
            infoRow(
                title: "Идентификатор",
                value: bridge.id.isEmpty ? "Не определен" : formatBridgeId(bridge.id),
                isMonospaced: true
            )
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Версия ПО
            if let config = viewModel.bridgeCapabilities {
                infoRow(
                    title: "Программное обеспечение",
                    value: config.timezones?.first ?? "Неизвестно",
                    isMonospaced: true
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
            }
            
            // IP адрес
            infoRow(
                title: "IP-адрес",
                value: bridge.internalipaddress,
                isMonospaced: true
            )
            
            // MAC адрес если есть
            if let mac = bridge.macaddress {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                infoRow(
                    title: "MAC-адрес",
                    value: formatMacAddress(mac),
                    isMonospaced: true
                )
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Statistics Card
    
    private var statisticsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("СТАТИСТИКА")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatBox(
                    icon: "lightbulb.fill",
                    value: "\(viewModel.lightsViewModel.lights.count)",
                    label: "Ламп",
                    color: .yellow
                )
                
                StatBox(
                    icon: "square.3.layers.3d",
                    value: "\(viewModel.scenesViewModel.scenes.count)",
                    label: "Сцен",
                    color: .purple
                )
                
                StatBox(
                    icon: "square.grid.2x2",
                    value: "\(viewModel.groupsViewModel.groups.count)",
                    label: "Групп",
                    color: .blue
                )
                
                StatBox(
                    icon: "sensor",
                    value: "\(viewModel.sensorsViewModel.sensors.count)",
                    label: "Сенсоров",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Actions Card
    
    private var actionsCard: some View {
        VStack(spacing: 12) {
            // Обновить данные
            Button(action: {
                withAnimation {
                    isRefreshing = true
                }
                viewModel.refreshAll()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isRefreshing = false
                    }
                }
            }) {
                HStack {
                    if isRefreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Обновить данные")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isRefreshing)
            
            // Отключить мост
            Button(action: {
                showingDisconnectAlert = true
            }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Отключить мост")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red, lineWidth: 1)
                )
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - Helper Views
    
    private func infoRow(title: String, value: String, isMonospaced: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(isMonospaced ? .system(.body, design: .monospaced) : .body)
                .foregroundColor(.white)
                .textSelection(.enabled)
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch viewModel.connectionStatus {
        case .connected:
            return .green
        case .searching, .discovered, .needsAuthentication, .connecting:
            return .orange
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch viewModel.connectionStatus {
        case .connected:
            return "Подключено"
        case .searching:
            return "Поиск..."
        case .discovered:
            return "Найден"
        case .connecting:
            return "Подключение..."
        case .needsAuthentication:
            return "Требуется авторизация"
        case .disconnected:
            return "Отключено"
        case .error(let message):
            return "Ошибка: \(message)"
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatBridgeId(_ id: String) -> String {
        // Форматируем ID как в примере: ECB5FAFFFE896811
        return id.uppercased()
    }
    
    private func formatMacAddress(_ mac: String) -> String {
        // Форматируем MAC адрес: XX:XX:XX:XX:XX:XX
        let cleaned = mac.replacingOccurrences(of: ":", with: "").uppercased()
        var formatted = ""
        
        for (index, char) in cleaned.enumerated() {
            if index > 0 && index % 2 == 0 {
                formatted += ":"
            }
            formatted.append(char)
        }
        
        return formatted
    }
}

// MARK: - Stat Box Component

struct StatBox: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Preview

struct BridgeStatusView_Previews: PreviewProvider {
    static var previews: some View {
        BridgeStatusView(viewModel: AppViewModel(dataPersistenceService: nil))
            .preferredColorScheme(.dark)
    }
}
