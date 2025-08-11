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
    @State private var hasReturnedFromSettings = false
    
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
//        .sheet(isPresented: $showingScanner) {
//            QRCodeScannerView(completion: handleScannedCode)
//        }
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Приложение вернулось из фона (например, из настроек)
            if hasReturnedFromSettings {
                print("📱 Приложение вернулось из настроек, проверяем разрешение...")
                hasReturnedFromSettings = false
                // Небольшая задержка для стабильности
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    checkLocalNetworkPermissionAndRetrySearch()
                }
            }
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
    
    /// Обработка HomeKit QR-кода
    private func handleHomeKitQRCode(_ code: String) {
        print("🔄 Начинаем автоматический поиск Bridge после сканирования HomeKit QR-кода")
        
        // Извлекаем setup code из HomeKit URI если нужно
        // Формат: X-HM://0024SIN3EQ0EB где SIN3EQ0EB - setup code
        let setupCode = extractHomeKitSetupCode(from: code)
        print("🔑 Setup код HomeKit: \(setupCode)")
        
        // Запускаем автоматический поиск мостов
        searchForBridges()
    }
    
    /// Извлечение setup кода из HomeKit URI
    private func extractHomeKitSetupCode(from uri: String) -> String {
        // X-HM://0024SIN3EQ0EB -> извлекаем SIN3EQ0EB
        if let range = uri.range(of: "X-HM://") {
            let afterPrefix = String(uri[range.upperBound...])
            // Пропускаем первые 4 символа (0024) и берем остальное
            if afterPrefix.count > 4 {
                return String(afterPrefix.dropFirst(4))
            }
        }
        return ""
    }
    
    /// Показать алерт о неподдерживаемом QR-коде
    private func showUnsupportedQRAlert() {
        // В реальном приложении здесь будет SwiftUI Alert
        print("⚠️ Показываем алерт: Неподдерживаемый QR-код. Попробуйте автоматический поиск.")
        
        // Предлагаем запустить автоматический поиск
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.searchForBridges()
        }
    }
    
    /// Обработка отсканированного QR-кода
    private func handleScannedCode(_ code: String) {
        print("📱 handleScannedCode вызван с кодом: '\(code)'")
        showingScanner = false
        
        // Проверяем тип QR-кода
        if code.hasPrefix("X-HM://") {
            print("🏠 Обнаружен HomeKit Setup URI: \(code)")
            // HomeKit QR-код - запускаем автоматический поиск Bridge
            handleHomeKitQRCode(code)
        } else if let bridgeId = parseBridgeId(from: code) {
            print("✅ Bridge ID успешно извлечен: \(bridgeId)")
            connectToBridge(withId: bridgeId)
        } else {
            print("❌ Неподдерживаемый формат QR-кода: '\(code)'")
            // Показываем алерт с предложением автоматического поиска
            showUnsupportedQRAlert()
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
    
    /// Поиск мостов в сети согласно Philips Hue Discovery Guide
    private func searchForBridges() {
        print("🔍 Запускаем комплексный поиск Hue Bridge...")
        isSearching = true
        
        // Очищаем предыдущие результаты
        viewModel.discoveredBridges.removeAll()
        
        // Запускаем поиск (mDNS + N-UPnP параллельно)
        viewModel.searchForBridges()
        
        // Таймаут поиска согласно рекомендациям:
        // - UPnP/mDNS: максимум 5 секунд
        // - N-UPnP: максимум 8 секунд
        // - Общий таймаут: 10 секунд
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.isSearching = false
            self.handleDiscoveryResults()
        }
    }
    
    /// Обработка результатов поиска мостов
    private func handleDiscoveryResults() {
        let foundBridges = viewModel.discoveredBridges
        
        print("📊 Результаты поиска: найдено \(foundBridges.count) мостов")
        
        if foundBridges.isEmpty {
            print("❌ Мосты не найдены. Предлагаем ручной ввод IP.")
            showNoBridgesFoundAlert()
        } else if foundBridges.count == 1 {
            print("✅ Найден один мост: \(foundBridges[0].internalipaddress)")
            selectedBridge = foundBridges.first
            if let bridge = selectedBridge {
                validateAndConnectToBridge(bridge)
            }
        } else {
            print("🔀 Найдено несколько мостов: \(foundBridges.count)")
            showMultipleBridgesSelection(foundBridges)
        }
    }
    
    /// Показать алерт когда мосты не найдены
    private func showNoBridgesFoundAlert() {
        // Проверяем, была ли ошибка связана с отказом в разрешении
        if let error = viewModel.error as? HueAPIError,
           case .localNetworkPermissionDenied = error {
            print("🚫 Показываем алерт об отказе в разрешении локальной сети")
            showLocalNetworkPermissionDeniedAlert()
        } else {
            // В реальном приложении здесь будет SwiftUI Alert с предложением:
            // 1. Попробовать еще раз
            // 2. Ввести IP вручную
            // 3. Проверить подключение Bridge к сети
            print("⚠️ Алерт: Мосты не найдены. Попробуйте ввести IP вручную.")
            
            // Автоматически открываем ручной ввод через 2 секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showingManualEntry = true
            }
        }
    }
    
    /// Показать алерт об отказе в разрешении локальной сети
    private func showLocalNetworkPermissionDeniedAlert() {
        print("🚫 Алерт: Разрешение локальной сети отклонено")
        print("📱 Автоматически открываем настройки iOS для включения разрешения...")
        
        // Автоматически открываем настройки iOS на странице с разрешениями приложения
        openAppSettingsForLocalNetwork()
    }
    
    /// Открыть настройки iOS для включения разрешения локальной сети
    private func openAppSettingsForLocalNetwork() {
        // Отмечаем что пользователь идет в настройки
        hasReturnedFromSettings = true
        
        // Открываем настройки приложения в iOS
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                print("🔧 Открываем настройки iOS...")
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        print("✅ Настройки iOS успешно открыты")
                        print("👤 Пользователь должен:")
                        print("   1. Найти раздел 'Локальная сеть'")
                        print("   2. Включить переключатель")
                        print("   3. Вернуться в приложение")
                    } else {
                        print("❌ Не удалось открыть настройки")
                        self.hasReturnedFromSettings = false
                        // Fallback: показываем ручной ввод
                        DispatchQueue.main.async {
                            self.showingManualEntry = true
                        }
                    }
                }
            } else {
                print("❌ Невозможно открыть настройки - URL не поддерживается")
                hasReturnedFromSettings = false
                // Fallback: показываем ручной ввод
                showingManualEntry = true
            }
        } else {
            print("❌ Невозможно создать URL для настроек")
            hasReturnedFromSettings = false
            // Fallback: показываем ручной ввод
            showingManualEntry = true
        }
    }
    
    /// Проверить разрешение локальной сети и повторить поиск
    private func checkLocalNetworkPermissionAndRetrySearch() {
        print("🔄 Проверяем разрешение и повторяем поиск мостов...")
        
        // Очищаем предыдущие ошибки
        viewModel.error = nil
        
        // Повторяем поиск мостов
        searchForBridges()
    }
    
    /// Показать выбор из нескольких мостов
    private func showMultipleBridgesSelection(_ bridges: [Bridge]) {
        // В реальном приложении здесь будет ActionSheet или NavigationLink
        print("📋 Показываем список мостов для выбора:")
        for (index, bridge) in bridges.enumerated() {
            print("  \(index + 1). \(bridge.name ?? "Hue Bridge") - \(bridge.internalipaddress)")
        }
        
        // Для демонстрации выбираем первый мост
        selectedBridge = bridges.first
        if let bridge = selectedBridge {
            validateAndConnectToBridge(bridge)
        }
    }
    
    /// Валидация и подключение к мосту
    private func validateAndConnectToBridge(_ bridge: Bridge) {
        print("🔍 Валидируем мост: \(bridge.internalipaddress)")
        
        // Проверяем что это действительно Hue Bridge
        // через запрос к /description.xml или /api/config
        viewModel.validateBridge(bridge) {  isValid in
            DispatchQueue.main.async {
                if isValid {
                    print("✅ Мост прошел валидацию")
                    self.startLinkButtonProcess(for: bridge)
                } else {
                    print("❌ Мост не прошел валидацию")
                    self.showInvalidBridgeAlert()
                }
            }
        }
    }
    
    /// Показать алерт о невалидном мосте
    private func showInvalidBridgeAlert() {
        print("⚠️ Алерт: Устройство не является Hue Bridge")
        
        // Предлагаем попробовать снова
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.searchForBridges()
        }
    }
    
    /// Подключение к мосту по ID
    private func connectToBridge(withId bridgeId: String) {
        // Сначала ищем мост в сети
        isSearching = true
        viewModel.searchForBridges()
        
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
        
        // Подключаемся к мосту
        viewModel.connectToBridge(bridge)
        
        // Запускаем непрерывные попытки авторизации без таймера обратного отсчета
        linkButtonTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // Пробуем создать пользователя каждые 2 секунды
            attemptCreateUser()
        }
    }
    
    /// Попытка создать пользователя
    private func attemptCreateUser() {
        viewModel.createUser(appName: "BulbsHUE") {  success in
            if success {
                print("✅ Пользователь создан через BridgeSetupView!")
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
    }
}

// MARK: - QR Code Scanner View (закомментировано - может понадобиться в будущем)
/*
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
*/

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
        BridgeSetupView(viewModel: AppViewModel(dataPersistenceService: nil))
    }
}


