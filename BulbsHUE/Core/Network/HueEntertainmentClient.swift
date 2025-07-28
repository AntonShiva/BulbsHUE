
import Foundation
import Network

/// Клиент для Entertainment Streaming API
/// Использует DTLS/UDP для низкой задержки (50-60Hz)
class HueEntertainmentClient {
    
    // MARK: - Properties
    
    /// IP адрес моста
    private let bridgeIP: String
    
    /// Application key
    private let applicationKey: String
    
    /// Client key для DTLS
    private let clientKey: String
    
    /// UDP соединение
    private var connection: NWConnection?
    
    /// Очередь для отправки
    private let queue = DispatchQueue(label: "com.hue.entertainment", qos: .userInteractive)
    
    /// Таймер для streaming
    private var streamTimer: Timer?
    
    /// Активная конфигурация
    private var activeConfiguration: EntertainmentConfiguration?
    
    /// Частота обновления (рекомендуется 50-60Hz)
    private let updateFrequency: Double = 60.0
    
    // MARK: - Initialization
    
    init(bridgeIP: String, applicationKey: String, clientKey: String) {
        self.bridgeIP = bridgeIP
        self.applicationKey = applicationKey
        self.clientKey = clientKey
    }
    
    // MARK: - Public Methods
    
    /// Запускает entertainment сессию
    /// - Parameter configuration: Конфигурация развлекательной зоны
    func startSession(configuration: EntertainmentConfiguration, completion: @escaping (Bool) -> Void) {
        activeConfiguration = configuration
        
        // Настраиваем DTLS параметры
        let parameters = NWParameters.dtls
        let tlsOptions = NWProtocolTLS.Options()
        
        // Настраиваем PSK (Pre-Shared Key)
        let pskData = clientKey.data(using: .utf8)!
        let keyData = applicationKey.data(using: .utf8)!
        
        pskData.withUnsafeBytes { pskBytes in
            keyData.withUnsafeBytes { keyBytes in
                let pskDispatchData = DispatchData(bytes: pskBytes)
                let keyDispatchData = DispatchData(bytes: keyBytes)
                
                sec_protocol_options_add_pre_shared_key(
                    tlsOptions.securityProtocolOptions,
                    pskDispatchData as __DispatchData,
                    keyDispatchData as __DispatchData
                )
            }
        }
        
        // Устанавливаем cipher suite: TLS_PSK_WITH_AES_128_GCM_SHA256
        sec_protocol_options_set_min_tls_protocol_version(
            tlsOptions.securityProtocolOptions,
            .DTLSv12
        )
        
        parameters.defaultProtocolStack.applicationProtocols.insert(tlsOptions, at: 0)
        
        // Создаем соединение
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(bridgeIP),
            port: NWEndpoint.Port(rawValue: 2100)!
        )
        
        connection = NWConnection(to: endpoint, using: parameters)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Entertainment connection ready")
                self?.startStreaming()
                completion(true)
            case .failed(let error):
                print("Entertainment connection failed: \(error)")
                completion(false)
            default:
                break
            }
        }
        
        connection?.start(queue: queue)
    }
    
    /// Останавливает entertainment сессию
    func stopSession() {
        streamTimer?.invalidate()
        streamTimer = nil
        connection?.cancel()
        connection = nil
        activeConfiguration = nil
    }
    
    /// Отправляет состояния ламп
    /// - Parameter lightStates: Массив состояний для каналов (до 10)
    func sendLightStates(_ lightStates: [(channelId: Int, color: (r: UInt8, g: UInt8, b: UInt8))]) {
        guard let connection = connection else { return }
        
        // Формируем пакет согласно протоколу
        var packet = Data()
        
        // Protocol header
        packet.append("HueStream".data(using: .utf8)!)
        
        // Version (2.0)
        packet.append(contentsOf: [0x02, 0x00])
        
        // Sequence ID (можно инкрементировать для отслеживания)
        packet.append(contentsOf: [0x00, 0x00])
        
        // Reserved
        packet.append(contentsOf: [0x00, 0x00])
        
        // Color space (RGB)
        packet.append(0x00)
        
        // Reserved
        packet.append(0x00)
        
        // Entertainment configuration ID
        if let configId = activeConfiguration?.id.data(using: .utf8) {
            packet.append(configId)
        }
        
        // Light data
        for (channelId, color) in lightStates {
            // Channel ID
            packet.append(UInt8(channelId))
            
            // RGB values (16-bit per channel для точности)
            let r16 = UInt16(color.r) << 8
            let g16 = UInt16(color.g) << 8
            let b16 = UInt16(color.b) << 8
            
            packet.append(contentsOf: withUnsafeBytes(of: r16.bigEndian) { Array($0) })
            packet.append(contentsOf: withUnsafeBytes(of: g16.bigEndian) { Array($0) })
            packet.append(contentsOf: withUnsafeBytes(of: b16.bigEndian) { Array($0) })
        }
        
        // Отправляем пакет
        connection.send(content: packet, completion: .contentProcessed { _ in
            // Обработка отправки
        })
    }
    
    // MARK: - Private Methods
    
    /// Запускает поток обновлений
    private func startStreaming() {
        let interval = 1.0 / updateFrequency
        
        streamTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // Здесь должна быть логика генерации и отправки состояний
            // Это зависит от конкретного use case (музыка, видео, игры)
        }
    }
}

// MARK: - Entertainment Effects

/// Базовый протокол для entertainment эффектов
protocol EntertainmentEffect {
    /// Генерирует состояния для текущего момента времени
    func generateStates(time: TimeInterval, channels: [EntertainmentChannel]) -> [(channelId: Int, color: (r: UInt8, g: UInt8, b: UInt8))]
}

/// Эффект пульсации
struct PulseEffect: EntertainmentEffect {
    let color: (r: UInt8, g: UInt8, b: UInt8)
    let frequency: Double
    
    func generateStates(time: TimeInterval, channels: [EntertainmentChannel]) -> [(channelId: Int, color: (r: UInt8, g: UInt8, b: UInt8))] {
        let brightness = (sin(time * frequency * 2 * .pi) + 1) / 2
        
        return channels.compactMap { channel in
            guard let channelId = channel.channel_id else { return nil }
            
            let r = UInt8(Double(color.r) * brightness)
            let g = UInt8(Double(color.g) * brightness)
            let b = UInt8(Double(color.b) * brightness)
            
            return (channelId, (r, g, b))
        }
    }
}

/// Эффект волны
struct WaveEffect: EntertainmentEffect {
    let color: (r: UInt8, g: UInt8, b: UInt8)
    let speed: Double
    
    func generateStates(time: TimeInterval, channels: [EntertainmentChannel]) -> [(channelId: Int, color: (r: UInt8, g: UInt8, b: UInt8))] {
        return channels.compactMap { channel in
            guard let channelId = channel.channel_id,
                  let position = channel.position else { return nil }
            
            // Волна идет по X координате
            let phase = position.x ?? 0.0
            let brightness = (sin((time * speed - phase) * 2 * .pi) + 1) / 2
            
            let r = UInt8(Double(color.r) * brightness)
            let g = UInt8(Double(color.g) * brightness)
            let b = UInt8(Double(color.b) * brightness)
            
            return (channelId, (r, g, b))
        }
    }
}
