//
//  UniversalItemControl.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 8/18/25.
//

import SwiftUI

/// Универсальный контрол для управления лампами и комнатами
/// Принимает данные через простой протокол ItemData
struct UniversalItemControl: View {
    // MARK: - Properties
    let data: ItemData
    let onToggle: (Bool) -> Void
    let onBrightnessChange: (Double) -> Void
    let onMenuTap: () -> Void
    
    // MARK: - State
    @State private var isOn: Bool
    @State private var brightness: Double
    
    // MARK: - Initialization
    init(
        data: ItemData,
        onToggle: @escaping (Bool) -> Void = { _ in },
        onBrightnessChange: @escaping (Double) -> Void = { _ in },
        onMenuTap: @escaping () -> Void = { }
    ) {
        self.data = data
        self.onToggle = onToggle
        self.onBrightnessChange = onBrightnessChange
        self.onMenuTap = onMenuTap
        
        // Инициализируем состояние из данных
        self._isOn = State(initialValue: data.isOn)
        self._brightness = State(initialValue: data.brightness)
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                // Основной контрол
                ControlView(
                    isOn: $isOn,
                    baseColor: data.color,
                    bulbName: data.name,
                    bulbType: data.type,
                    roomName: data.subtitle ?? "",
                    bulbIcon: data.iconName,
                    roomIcon: data.secondaryIcon ?? "",
                    onToggle: { newState in
                        isOn = newState
                        onToggle(newState)
                    },
                    onMenuTap: onMenuTap
                )
                
                // Индикатор статуса
                if !data.isAvailable {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red.opacity(0.6))
                            .frame(width: 8, height: 8)
                        Text(data.statusMessage)
                            .font(Font.custom("DMSans-Medium", size: 11))
                            .foregroundStyle(Color.red.opacity(0.8))
                            .textCase(.uppercase)
                    }
                    .adaptiveOffset(x: -10, y: -38)
                }
            }
            
            // Слайдер яркости (показываем только если поддерживается)
            if data.supportsBrightness {
                CustomSlider(
                    percent: $brightness,
                    color: data.color,
                    onChange: { value in
                        brightness = value
                        onBrightnessChange(value)
                    },
                    onCommit: { value in
                        brightness = value
                        onBrightnessChange(value)
                    }
                )
                .padding(.leading, 10)
            }
        }
        .onChange(of: data.isOn) { newValue in
            isOn = newValue
        }
        .onChange(of: data.brightness) { newValue in
            brightness = newValue
        }
    }
}

// MARK: - Protocol Definition

/// Протокол для данных, которые можно отображать в UniversalItemControl
protocol ItemData {
    /// Уникальный идентификатор
    var id: String { get }
    
    /// Название элемента
    var name: String { get }
    
    /// Тип элемента для отображения
    var type: String { get }
    
    /// Подзаголовок (опционально)
    var subtitle: String? { get }
    
    /// Название основной иконки
    var iconName: String { get }
    
    /// Название вторичной иконки (опционально)
    var secondaryIcon: String? { get }
    
    /// Включен ли элемент
    var isOn: Bool { get }
    
    /// Уровень яркости (0.0 - 100.0)
    var brightness: Double { get }
    
    /// Поддерживает ли управление яркостью
    var supportsBrightness: Bool { get }
    
    /// Доступен ли элемент
    var isAvailable: Bool { get }
    
    /// Сообщение о статусе
    var statusMessage: String { get }
    
    /// Цвет для отображения
    var color: Color { get }
}

// MARK: - Data Structs

/// Данные для отображения лампы
struct LightItemData: ItemData {
    let id: String
    let name: String
    let type: String
    let subtitle: String?
    let iconName: String
    let secondaryIcon: String?
    let isOn: Bool
    let brightness: Double
    let supportsBrightness: Bool
    let isAvailable: Bool
    let statusMessage: String
    let color: Color
    
    /// Создать данные лампы из Light объекта
    static func from(_ light: Light) -> LightItemData {
        // ✅ Используем тот же defaultWarmColor что и в ItemControlViewModel
        let defaultWarmColor = Color(hue: 0.13, saturation: 0.25, brightness: 1.0)
        
        return LightItemData(
            id: light.id,
            name: light.metadata.name,
            type: light.metadata.userSubtypeName ?? "LIGHT",
            subtitle: nil, // Можно добавить название комнаты
            iconName: light.metadata.userSubtypeIcon ?? "bulb",
            secondaryIcon: nil,
            isOn: light.on.on,
            brightness: Double(light.dimming?.brightness ?? 0),
            supportsBrightness: light.dimming != nil,
            isAvailable: light.isReachable,
            statusMessage: "Обесточена",
            color: defaultWarmColor // ✅ Используем стандартный цвет
        )
    }
}

/// Данные для отображения комнаты
struct RoomItemData: ItemData {
    let id: String
    let name: String
    let type: String
    let subtitle: String?
    let iconName: String
    let secondaryIcon: String?
    let isOn: Bool
    let brightness: Double
    let supportsBrightness: Bool
    let isAvailable: Bool
    let statusMessage: String
    let color: Color
    
    /// Создать данные комнаты из RoomEntity объекта
    static func from(_ room: RoomEntity) -> RoomItemData {
        // ✅ Используем тот же defaultWarmColor что и у ламп
        let defaultWarmColor = Color(hue: 0.13, saturation: 0.25, brightness: 1.0)
        
        return RoomItemData(
            id: room.id,
            name: room.name,
            type: room.type.displayName,
            subtitle: "\(room.lightCount) lights",
            iconName: room.iconName, // ✅ Используем сохраненную иконку подтипа
            secondaryIcon: nil,
            isOn: room.isActive,
            brightness: 50.0, // TODO: Вычислить среднюю яркость ламп комнаты
            supportsBrightness: !room.isEmpty,
            isAvailable: !room.isEmpty,
            statusMessage: "Пустая",
            color: defaultWarmColor // ✅ Используем стандартный цвет, как у ламп
        )
    }
}

// MARK: - Convenience Extensions

extension UniversalItemControl {
    /// Инициализатор для лампы
    static func forLight(
        _ light: Light,
        onToggle: @escaping (Bool) -> Void = { _ in },
        onBrightnessChange: @escaping (Double) -> Void = { _ in },
        onMenuTap: @escaping () -> Void = { }
    ) -> UniversalItemControl {
        return UniversalItemControl(
            data: LightItemData.from(light),
            onToggle: onToggle,
            onBrightnessChange: onBrightnessChange,
            onMenuTap: onMenuTap
        )
    }
    
    /// Инициализатор для комнаты
    static func forRoom(
        _ room: RoomEntity,
        onToggle: @escaping (Bool) -> Void = { _ in },
        onBrightnessChange: @escaping (Double) -> Void = { _ in },
        onMenuTap: @escaping () -> Void = { }
    ) -> UniversalItemControl {
        return UniversalItemControl(
            data: RoomItemData.from(room),
            onToggle: onToggle,
            onBrightnessChange: onBrightnessChange,
            onMenuTap: onMenuTap
        )
    }
}

#Preview("Light Control") {
    let mockLight = Light(
        id: "light_mock_01",
        type: "light",
        metadata: LightMetadata(name: "Smart Bulb", archetype: nil),
        on: OnState(on: true),
        dimming: Dimming(brightness: 75),
        color: nil,
        color_temperature: nil,
        effects: nil,
        effects_v2: nil,
        mode: nil,
        capabilities: nil,
        color_gamut_type: nil,
        color_gamut: nil,
        gradient: nil
    )
    
    UniversalItemControl.forLight(
        mockLight,
        onToggle: { isOn in
            print("💡 Light toggled: \(isOn)")
        },
        onBrightnessChange: { brightness in
            print("💡 Brightness: \(brightness)%")
        },
        onMenuTap: {
            print("💡 Menu tapped")
        }
    )
    .environmentObject(AppViewModel())
    .environmentObject(NavigationManager.shared)
}

#Preview("Room Control") {
    let mockRoom = RoomEntity(
        id: "room_mock_01",
        name: "Living Room",
        type: .livingRoom,
        subtypeName: "LIVING ROOM",
        iconName: "tr1", // ✅ Добавляем иконку
        lightIds: ["light1", "light2", "light3"],
        isActive: true,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    UniversalItemControl.forRoom(
        mockRoom,
        onToggle: { isOn in
            print("🏠 Room toggled: \(isOn)")
        },
        onBrightnessChange: { brightness in
            print("🏠 Room brightness: \(brightness)%")
        },
        onMenuTap: {
            print("🏠 Room menu tapped")
        }
    )
    .environmentObject(AppViewModel())
    .environmentObject(NavigationManager.shared)
}

#Preview("Both Controls") {
    VStack(spacing: 20) {
        // Лампа
        UniversalItemControl.forLight(
            Light(
                id: "light1",
                type: "light",
                metadata: LightMetadata(name: "Kitchen Light", userSubtypeName: "CEILING", userSubtypeIcon: "ceiling"),
                on: OnState(on: true),
                dimming: Dimming(brightness: 80),
                color: nil,
                color_temperature: nil,
                effects: nil,
                effects_v2: nil,
                mode: nil,
                capabilities: nil,
                color_gamut_type: nil,
                color_gamut: nil,
                gradient: nil
            )
        )
        
        // Комната
        UniversalItemControl.forRoom(
            RoomEntity(
                id: "room1",
                name: "Kitchen",
                type: .kitchen,
                subtypeName: "KITCHEN",
                iconName: "tr2", // ✅ Добавляем иконку
                lightIds: ["light1", "light2"],
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }
    .padding()
    .environmentObject(AppViewModel())
    .environmentObject(NavigationManager.shared)
}
