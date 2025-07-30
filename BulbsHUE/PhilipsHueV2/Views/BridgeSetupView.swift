//
//  BridgeSetupView.swift
//  PhilipsHueV2
//
//  Created by Anton Reasin on 28.07.2025.
//

import SwiftUI
import AVFoundation
import CodeScanner

/// View для настройки подключения к Hue Bridge
struct BridgeSetupView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingScanner = false
    @State private var showingManualEntry = false
    @State private var manualSerialNumber = ""
    @State private var isSearching = false
    @State private var showingLinkButtonAlert = false
    @State private var linkButtonTimer: Timer?
    @State private var linkButtonCountdown = 30
    @State private var selectedBridge: Bridge?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Логотип и заголовок
                VStack(spacing: 20) {
                    Image(systemName: "lightbulb.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("Настройка Philips Hue")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Подключите ваш Hue Bridge для начала работы")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Кнопки действий
                VStack(spacing: 16) {
                    // Сканирование QR-кода
                    Button(action: {
                        checkCameraPermission()
                    }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title2)
                            Text("Сканировать QR-код")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // Ручной ввод
                    Button(action: {
                        showingManualEntry = true
                    }) {
                        HStack {
                            Image(systemName: "keyboard")
                                .font(.title2)
                            Text("Ввести вручную")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    }
                    
                    // Автоматический поиск
                    Button(action: {
                        searchForBridges()
                    }) {
                        HStack {
                            if isSearching {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "wifi")
                                    .font(.title2)
                            }
                            Text(isSearching ? "Поиск..." : "Найти в сети")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green, lineWidth: 2)
                        )
                    }
                    .disabled(isSearching)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Информация внизу
                VStack(spacing: 8) {
                    Text("QR-код находится на задней части вашего Hue Bridge")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        // Открыть справку
                    }) {
                        Text("Нужна помощь?")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingScanner) {
            QRCodeScannerView(completion: handleScannedCode)
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView(serialNumber: $manualSerialNumber) { serial in
                handleManualEntry(serial)
            }
        }
        .alert("Нажмите кнопку Link", isPresented: $showingLinkButtonAlert) {
            Button("Отмена") {
                cancelLinkButton()
            }
        } message: {
            Text("Нажмите круглую кнопку Link на вашем Hue Bridge.\n\nОсталось времени: \(linkButtonCountdown) сек.")
        }
    }
    
    // MARK: - Methods
    
    /// Проверка разрешения камеры
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingScanner = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        showingScanner = true
                    }
                }
            }
        case .denied, .restricted:
            // Показать алерт с предложением открыть настройки
            showCameraPermissionAlert()
        @unknown default:
            break
        }
    }
    
    /// Показать алерт о разрешении камеры
    private func showCameraPermissionAlert() {
        // Реализация алерта
    }
    
    /// Обработка отсканированного QR-кода
    private func handleScannedCode(_ code: String) {
        print("📱 handleScannedCode вызван с кодом: '\(code)'")
        showingScanner = false
        
        // Парсим QR-код
        if let bridgeId = parseBridgeId(from: code) {
            print("✅ Bridge ID успешно извлечен: \(bridgeId)")
            connectToBridge(withId: bridgeId)
        } else {
            print("❌ Не удалось извлечь Bridge ID из кода: '\(code)'")
            // Показываем алерт об ошибке
            DispatchQueue.main.async {
                // Здесь можно показать алерт пользователю
            }
        }
    }
    
    /// Обработка ручного ввода
    private func handleManualEntry(_ serial: String) {
        showingManualEntry = false
        
        if let bridgeId = parseBridgeId(from: serial) {
            connectToBridge(withId: bridgeId)
        }
    }
    
    /// Парсинг ID моста из различных форматов
    private func parseBridgeId(from input: String) -> String? {
        // Удаляем пробелы и приводим к верхнему регистру
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Проверяем различные форматы
        if cleaned.hasPrefix("S#") {
            // Формат S#12345678
            return String(cleaned.dropFirst(2))
        } else if cleaned.hasPrefix("HTTP") {
            // URL формат
            // Извлекаем ID из URL
            if let url = URL(string: cleaned),
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let idParam = components.queryItems?.first(where: { $0.name == "id" })?.value {
                return idParam
            }
        } else if cleaned.count == 8 || cleaned.count == 16 {
            // Просто серийный номер
            return cleaned
        }
        
        return nil
    }
    
    /// Поиск мостов в сети
    private func searchForBridges() {
        isSearching = true
        viewModel.discoverBridges()
        
        // Таймаут поиска
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            isSearching = false
            
            if !viewModel.discoveredBridges.isEmpty {
                // Показать список найденных мостов
                if viewModel.discoveredBridges.count == 1 {
                    selectedBridge = viewModel.discoveredBridges.first
                    if let bridge = selectedBridge {
                        startLinkButtonProcess(for: bridge)
                    }
                } else {
                    // Показать выбор из нескольких мостов
                }
            } else {
                // Показать сообщение, что мосты не найдены
            }
        }
    }
    
    /// Подключение к мосту по ID
    private func connectToBridge(withId bridgeId: String) {
        // Сначала ищем мост в сети
        isSearching = true
        viewModel.discoverBridges()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isSearching = false
            
            // Ищем мост с нужным ID
            if let bridge = viewModel.discoveredBridges.first(where: { $0.id == bridgeId }) {
                selectedBridge = bridge
                startLinkButtonProcess(for: bridge)
            } else {
                // Мост не найден
                // Показать ошибку
            }
        }
    }
    
    /// Начать процесс нажатия кнопки Link
    private func startLinkButtonProcess(for bridge: Bridge) {
        selectedBridge = bridge
        showingLinkButtonAlert = true
        linkButtonCountdown = 30
        
        // Подключаемся к мосту
        viewModel.connectToBridge(bridge)
        
        // Запускаем таймер для попыток авторизации
        linkButtonTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            linkButtonCountdown -= 1
            
            if linkButtonCountdown % 3 == 0 {
                // Пробуем создать пользователя каждые 3 секунды
                attemptCreateUser()
            }
            
            if linkButtonCountdown <= 0 {
                cancelLinkButton()
            }
        }
    }
    
    /// Попытка создать пользователя
    private func attemptCreateUser() {
        viewModel.createUser(appName: "PhilipsHueV2") {  success in
            if success {
                self.cancelLinkButton()
                // Успешное подключение
            }
        }
    }
    
    /// Отмена процесса Link Button
    private func cancelLinkButton() {
        linkButtonTimer?.invalidate()
        linkButtonTimer = nil
        showingLinkButtonAlert = false
        linkButtonCountdown = 30
    }
}

// MARK: - QR Code Scanner View

struct QRCodeScannerView: View {
    let completion: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            CodeScannerView(
                codeTypes: [.qr],
                scanMode: .continuous,
                showViewfinder: true,
                simulatedData: "S#12345678", // Для симулятора
                completion: handleScan
            )
            .navigationTitle("Сканировать QR-код")
            .navigationBarItems(
                leading: Button("Отмена") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func handleScan(response: Result<ScanResult, ScanError>) {
        switch response {
        case .success(let result):
            completion(result.string)
        case .failure(let error):
            print("Ошибка сканирования: \(error)")
        }
    }
}

// MARK: - Manual Entry View

struct ManualEntryView: View {
    @Binding var serialNumber: String
    let completion: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Введите серийный номер")
                    .font(.headline)
                    .padding(.top, 40)
                
                Text("Серийный номер находится на задней части вашего Hue Bridge и начинается с S#")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Поле ввода
                VStack(alignment: .leading, spacing: 8) {
                    Text("Серийный номер")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("S#12345678", text: $serialNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .focused($isFocused)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Изображение-подсказка
                Image(systemName: "qrcode")
                    .font(.system(size: 100))
                    .foregroundColor(.gray.opacity(0.3))
                    .padding(.top, 40)
                
                Spacer()
                
                // Кнопка подключения
                Button(action: {
                    if !serialNumber.isEmpty {
                        completion(serialNumber)
                    }
                }) {
                    Text("Подключить")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(serialNumber.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(serialNumber.isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationBarItems(
                leading: Button("Отмена") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                isFocused = true
            }
        }
    }
}

// MARK: - Preview

struct BridgeSetupView_Previews: PreviewProvider {
    static var previews: some View {
        BridgeSetupView(viewModel: AppViewModel())
    }
}


