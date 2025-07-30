//
//  BridgeSetupView.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 30.07.2025.
//



import SwiftUI
import AVFoundation
import CodeScanner

/// View для настройки подключения к Hue Bridge
struct BridgeSetupView: View {
    @EnvironmentObject var viewModel: AppViewModel
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
        showingScanner = false
        
        // Парсим QR-код
        // Формат: S#12345678 или полный URL
        if let bridgeId = parseBridgeId(from: code) {
            connectToBridge(withId: bridgeId)
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
        // Удаляем пробелы и символы новой строки
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 Парсинг QR-кода: '\(cleaned)'")
        
        // Проверяем различные форматы
        if cleaned.hasPrefix("S#") || cleaned.hasPrefix("s#") {
            // Формат S#12345678
            let bridgeId = String(cleaned.dropFirst(2))
            print("✅ Извлечен Bridge ID из S#: \(bridgeId)")
            return bridgeId
        } else if cleaned.hasPrefix("X-HM://") {
            // Формат Philips Hue X-HM://ID  
            // Пример: X-HM://0024SIN3EQ0EB
            let rawId = String(cleaned.dropFirst(7))
            
            // Преобразуем в правильный формат Bridge ID
            // Первые 4 символа (0024) - MAC начало, остальные - серийный номер
            if rawId.count >= 4 {
                let macStart = String(rawId.prefix(4))
                let serial = String(rawId.dropFirst(4))
                
                // Формируем полный Bridge ID в формате MAC:serial
                let bridgeId = "\(macStart.lowercased())\(serial.lowercased())"
                print("✅ Извлечен Bridge ID из X-HM: \(rawId) -> \(bridgeId)")
                return bridgeId
            } else {
                print("✅ Извлечен Bridge ID из X-HM (прямо): \(rawId)")
                return rawId.lowercased()
            }
        } else if cleaned.lowercased().hasPrefix("http") {
            // URL формат - пробуем найти ID в разных местах
            if let url = URL(string: cleaned) {
                // Сначала проверяем query параметры
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                    if let idParam = components.queryItems?.first(where: { $0.name.lowercased() == "id" })?.value {
                        print("✅ Извлечен Bridge ID из URL query: \(idParam)")
                        return idParam
                    }
                    
                    // Пробуем найти в фрагменте
                    if let fragment = components.fragment, !fragment.isEmpty {
                        print("✅ Извлечен Bridge ID из URL fragment: \(fragment)")
                        return fragment
                    }
                }
                
                // Пробуем найти ID в конце пути
                let pathComponents = url.pathComponents
                if let lastComponent = pathComponents.last, lastComponent.count >= 8 {
                    print("✅ Извлечен Bridge ID из URL path: \(lastComponent)")
                    return lastComponent
                }
            }
        } else if cleaned.range(of: #"^[A-Fa-f0-9]{12,16}$"#, options: .regularExpression) != nil {
            // Хексадецимальный серийный номер (12-16 символов)
            print("✅ Извлечен Bridge ID (hex): \(cleaned)")
            return cleaned.lowercased()
        } else if cleaned.range(of: #"^[A-Za-z0-9]{8,16}$"#, options: .regularExpression) != nil {
            // Альфанумерический серийный номер (8-16 символов)
            print("✅ Извлечен Bridge ID (alphanum): \(cleaned)")
            return cleaned.lowercased()
        }
        
        print("❌ Не удалось извлечь Bridge ID из: '\(cleaned)'")
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
        print("🔍 Начинаем поиск моста с ID: \(bridgeId)")
        
        // Сначала ищем мост в сети
        isSearching = true
        viewModel.discoverBridges()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isSearching = false
            
            print("📡 Найдено мостов: \(viewModel.discoveredBridges.count)")
            for bridge in viewModel.discoveredBridges {
                print("   - Мост ID: \(bridge.id), IP: \(bridge.internalipaddress)")
            }
            
            // Ищем мост с нужным ID
            if let bridge = viewModel.discoveredBridges.first(where: { $0.id == bridgeId }) {
                print("✅ Найден мост: \(bridge.id) по адресу \(bridge.internalipaddress)")
                selectedBridge = bridge
                startLinkButtonProcess(for: bridge)
            } else {
                // Мост не найден - пробуем прямое подключение
                print("❌ Мост с ID \(bridgeId) не найден в сети, пробуем прямое подключение")
                self.tryDirectConnection(bridgeId: bridgeId)
            }
        }
    }
    
    /// Попытка прямого подключения к мосту по серийному номеру
    private func tryDirectConnection(bridgeId: String) {
        print("🔗 Пробуем прямое подключение к мосту: \(bridgeId)")
        
        // Пробуем подключиться по стандартным IP-адресам в локальной сети
        var commonIPs: [String] = []
        
        // Генерируем список наиболее вероятных IP адресов
        for subnet in ["192.168.1", "192.168.0", "10.0.0"] {
            for i in 1...10 {  // Уменьшаем диапазон для быстрого поиска
                commonIPs.append("\(subnet).\(i)")
            }
        }
        
        // Добавляем популярные адреса роутеров
        commonIPs.append(contentsOf: [
            "192.168.1.1", "192.168.0.1", "10.0.0.1", 
            "192.168.1.254", "192.168.0.254",
            "192.168.2.1", "192.168.100.1"
        ])
        
        // Убираем дубликаты
        commonIPs = Array(Set(commonIPs))
        
        // Пробуем каждый IP адрес с задержкой чтобы не перегружать сеть
        var foundBridge = false
        for (index, ip) in commonIPs.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                if !foundBridge {
                    self.checkBridgeAtIP(ip: ip, expectedId: bridgeId)
                }
            }
        }
        
        // Если не найдем через 15 секунд, показываем ошибку
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if self.selectedBridge == nil {
                print("❌ Не удалось найти мост \(bridgeId)")
                // Показываем пользователю сообщение об ошибке
                self.showManualIPEntry()
            }
        }
    }
    
    /// Показать ввод IP адреса вручную
    private func showManualIPEntry() {
        // Здесь можно добавить alert для ввода IP адреса вручную
        print("💡 Предложить пользователю ввести IP адрес вручную")
    }
    
    /// Проверяет, совпадают ли ID мостов (гибкое сравнение)
    private func bridgeIdMatches(config: String, expected: String) -> Bool {
        let configLower = config.lowercased().replacingOccurrences(of: ":", with: "")
        let expectedLower = expected.lowercased().replacingOccurrences(of: ":", with: "")
        
        // Прямое совпадение
        if configLower == expectedLower {
            return true
        }
        
        // Проверяем, содержится ли одно в другом
        if configLower.contains(expectedLower) || expectedLower.contains(configLower) {
            return true
        }
        
        // Проверяем последние 6-8 символов (часто совпадают)
        if configLower.count >= 6 && expectedLower.count >= 6 {
            let configSuffix = String(configLower.suffix(6))
            let expectedSuffix = String(expectedLower.suffix(6))
            if configSuffix == expectedSuffix {
                return true
            }
        }
        
        return false
    }
    
    /// Проверяет мост по конкретному IP адресу
    private func checkBridgeAtIP(ip: String, expectedId: String) {
        // Пробуем сначала HTTPS
        checkBridgeAtIPWithProtocol(ip: ip, expectedId: expectedId, useHTTPS: true) { success in
            if !success {
                // Если HTTPS не работает, пробуем HTTP
                self.checkBridgeAtIPWithProtocol(ip: ip, expectedId: expectedId, useHTTPS: false) { _ in }
            }
        }
    }
    
    /// Проверяет мост по IP с указанием протокола
    private func checkBridgeAtIPWithProtocol(ip: String, expectedId: String, useHTTPS: Bool, completion: @escaping (Bool) -> Void) {
        let protocolIP = useHTTPS ? "https" : "http"
        
        // Пробуем разные endpoints
        let endpoints = [
            "\(protocolIP)://\(ip)/api/config",           // API v1
            "\(protocolIP)://\(ip)/clip/v2/resource/config", // API v2
            "\(protocolIP)://\(ip)/description.xml"       // UPnP
        ]
        
        var foundBridge = false
        
        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 3.0
            
            let task = URLSession.shared.dataTask(with: request) {  data, response, error in
                guard !foundBridge,
                      let data = data,
                      error == nil else {
                    return
                }
                
                var bridgeConfig: String?
                
                if endpoint.contains("description.xml") {
                    // UPnP XML response
                    if let xmlString = String(data: data, encoding: .utf8),
                       xmlString.contains("Philips hue") || xmlString.contains("hue bridge") {
                        // Извлекаем серийный номер из XML
                        let pattern = #"<serialNumber>([^<]+)</serialNumber>"#
                        if let range = xmlString.range(of: pattern, options: .regularExpression) {
                            let match = String(xmlString[range])
                            bridgeConfig = match.replacingOccurrences(of: "<serialNumber>", with: "")
                                              .replacingOccurrences(of: "</serialNumber>", with: "")
                        }
                    }
                } else {
                    // JSON response
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        bridgeConfig = json["bridgeid"] as? String ??
                                     json["mac"] as? String ??
                                     json["serialnumber"] as? String
                    }
                }
                
                // Проверяем, совпадает ли ID
                if let bridgeConfig = bridgeConfig,
                   self.bridgeIdMatches(config: bridgeConfig, expected: expectedId) == true {
                    
                    foundBridge = true
                    print("✅ Найден мост по прямому подключению: \(ip) (\(protocolIP.uppercased()))")
                    
                    DispatchQueue.main.async {
                        let bridge = Bridge(
                            id: expectedId,
                            internalipaddress: ip,
                            port: useHTTPS ? 443 : 80
                        )
                        self.selectedBridge = bridge
                        self.startLinkButtonProcess(for: bridge)
                        completion(true)
                    }
                    return
                }
            }
            
            task.resume()
        }
        
        // Если за 2 секунды ничего не найдено
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if !foundBridge {
                completion(false)
            }
        }
    }
    
    /// Начать процесс нажатия кнопки Link
    private func startLinkButtonProcess(for bridge: Bridge) {
        print("🔗 Начинаем процесс авторизации с мостом: \(bridge.id)")
        
        selectedBridge = bridge
        showingLinkButtonAlert = true
        linkButtonCountdown = 30
        
        // Подключаемся к мосту
        print("📞 Подключаемся к мосту по адресу: \(bridge.internalipaddress)")
        viewModel.connectToBridge(bridge)
        
        // Запускаем таймер для попыток авторизации
        linkButtonTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            linkButtonCountdown -= 1
            
            if linkButtonCountdown % 3 == 0 {
                // Пробуем создать пользователя каждые 3 секунды
                print("🔐 Попытка авторизации (осталось: \(linkButtonCountdown) сек)")
                attemptCreateUser()
            }
            
            if linkButtonCountdown <= 0 {
                print("⏰ Время авторизации истекло")
                cancelLinkButton()
            }
        }
    }
    
    /// Попытка создать пользователя
    private func attemptCreateUser() {
        viewModel.createUserEnhanced(appName: "BulbsHUE") { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let success):
                    if success {
                        self.cancelLinkButton()
                        // Сохраняем учетные данные и переходим к главному экрану
                        self.viewModel.saveCredentials()
                        print("Успешное подключение к мосту!")
                    }
                case .failure(let error):
                    if case LinkButtonError.notPressed = error {
                        // Продолжаем попытки - кнопка еще не нажата
                        print("Кнопка Link не нажата, продолжаем...")
                    } else {
                        // Другие ошибки - останавливаем процесс
                        print("Ошибка подключения: \(error.localizedDescription)")
                        self.cancelLinkButton()
                    }
                }
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


#Preview {
    @Previewable @EnvironmentObject var viewModel: AppViewModel
    BridgeSetupView(viewModel: _viewModel)
        .environmentObject(AppViewModel())
}
