
//
//  LightDiscoveryView.swift
//  BulbsHUE
//
//  Экран для добавления новых ламп Philips Hue
//

import SwiftUI

#Preview {
   LightsListView()
        .environmentObject(NavigationManager.shared)
        .environmentObject(AppViewModel())
        
}
/// Главный экран со списком ламп и кнопкой добавления
struct LightsListView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingAddLight = false
    @State private var selectedLight: Light?
    
    var lightsViewModel: LightsViewModel {
        appViewModel.lightsViewModel
    }
    
    var groupsViewModel: GroupsViewModel {
        appViewModel.groupsViewModel
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Фоновый градиент
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.2),
                        Color(red: 0.02, green: 0.05, blue: 0.15)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Заголовок
                    HStack {
                        Text("Мои лампы")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Кнопка добавления
                        Button(action: {
                            showingAddLight = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    
                    if lightsViewModel.lights.isEmpty {
                        // Пустое состояние
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "lightbulb.slash")
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.3))
                            
                            Text("Нет добавленных ламп")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Button("Добавить лампу") {
                                showingAddLight = true
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.horizontal, 60)
                            
                            Spacer()
                        }
                    } else {
                        // Список ламп
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(lightsViewModel.lights) { light in
                                    LightRowView(
                                        light: light,
                                        roomName: getRoomName(for: light)
                                    )
                                    .onTapGesture {
                                        selectedLight = light
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAddLight) {
            AddLightView()
                .environmentObject(appViewModel)
        }
        .sheet(item: $selectedLight) { light in
            // Детальный экран управления лампой
            LightDetailView(light: light)
                .environmentObject(appViewModel)
        }
        .onAppear {
            // Загружаем данные при появлении экрана
            lightsViewModel.loadLights()
            groupsViewModel.loadGroups()
        }
    }
    
    // Получение названия комнаты для лампы
    private func getRoomName(for light: Light) -> String {
        // В API v2 связь между лампами и комнатами хранится в группах
        // Здесь упрощенная логика - в реальном приложении нужно найти группу, содержащую эту лампу
        return light.metadata.archetype ?? "Без комнаты"
    }
}

/// Строка с информацией о лампе
struct LightRowView: View {
    let light: Light
    let roomName: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Иконка состояния
            Image(systemName: light.on.on ? "lightbulb.fill" : "lightbulb")
                .font(.title2)
                .foregroundColor(light.on.on ? .yellow : .white.opacity(0.3))
                .frame(width: 40)
            
            // Информация о лампе
            VStack(alignment: .leading, spacing: 4) {
                Text(light.metadata.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(roomName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Переключатель
            Toggle("", isOn: .constant(light.on.on))
                .labelsHidden()
                .disabled(true) // Только для отображения
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

/// Экран добавления новой лампы
struct AddLightView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingManualAdd = false
    @State private var showingNetworkSearch = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Фоновый градиент как на скриншоте
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.15, blue: 0.35),
                        Color(red: 0.05, green: 0.1, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // Заголовок
                    HStack {
                        Text("NEW BULB")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Иконка лампы
                    ZStack {
                        // Лучи вокруг лампы
                        ForEach(0..<8) { index in
                            Rectangle()
                                .fill(Color.yellow.opacity(0.8))
                                .frame(width: 3, height: 20)
                                .offset(y: -60)
                                .rotationEffect(.degrees(Double(index) * 45))
                        }
                        
                        // Лампа
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.white)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .padding(.top, 40)
                    
                    // Важная информация
                    VStack(spacing: 8) {
                        Text("IMPORTANT")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("MAKE SURE THE LIGHTS\nAND SMART PLUGS YOU WANT TO ADD\nARE CONNECTED TO POWER")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    Spacer()
                    
                    // Кнопки действий
                    VStack(spacing: 20) {
                        // Использовать серийный номер
                        Button(action: {
                            showingManualAdd = true
                        }) {
                            Text("USE SERIAL NUMBER")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(28)
                        }
                        
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        // Поиск в сети
                        Button(action: {
                            showingNetworkSearch = true
                        }) {
                            Text("SEARCH IN NETWORK")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.4, green: 0.8, blue: 0.8),
                                            Color(red: 0.3, green: 0.7, blue: 0.7)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(28)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingManualAdd) {
            ManualAddLightView()
                .environmentObject(appViewModel)
        }
        .sheet(isPresented: $showingNetworkSearch) {
            NetworkSearchView()
                .environmentObject(appViewModel)
        }
    }
}

/// Экран ручного добавления лампы
struct ManualAddLightView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var lightName = ""
    @State private var selectedRoom = ""
    @State private var serialNumber = ""
    @State private var isCreating = false
    
    var groupsViewModel: GroupsViewModel {
        appViewModel.groupsViewModel
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Информация о лампе")) {
                    TextField("Название лампы", text: $lightName)
                    
                    TextField("Серийный номер (опционально)", text: $serialNumber)
                        .textInputAutocapitalization(.characters)
                }
                
                Section(header: Text("Комната")) {
                    Picker("Выберите комнату", selection: $selectedRoom) {
                        Text("Без комнаты").tag("")
                        
                        ForEach(groupsViewModel.rooms, id: \.id) { room in
                            Text(room.metadata?.name ?? "Комната")
                                .tag(room.id)
                        }
                    }
                }
                
                Section {
                    Button(action: createLight) {
                        if isCreating {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Создание...")
                            }
                        } else {
                            Text("Добавить лампу")
                        }
                    }
                    .disabled(lightName.isEmpty || isCreating)
                }
            }
            .navigationTitle("Добавить вручную")
            .navigationBarItems(
                leading: Button("Отмена") {
                    dismiss()
                }
            )
        }
    }
    
    private func createLight() {
        // В API v2 лампы обнаруживаются автоматически при подключении к питанию
        // Мы можем только переименовать уже обнаруженную лампу
        // Здесь заглушка для демонстрации
        isCreating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isCreating = false
            dismiss()
        }
    }
}

/// Экран поиска ламп в сети
struct NetworkSearchView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var isSearching = false
    @State private var foundLights: [Light] = []
    @State private var searchCompleted = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.1, blue: 0.2)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    if isSearching {
                        // Процесс поиска
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Поиск новых ламп...")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Убедитесь, что лампы включены")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    } else if searchCompleted {
                        // Результаты поиска
                        if foundLights.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "lightbulb.slash")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text("Новые лампы не найдены")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Убедитесь, что:\n• Лампы подключены к питанию\n• Лампы находятся рядом с мостом\n• Лампы совместимы с Philips Hue")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                
                                Button("Повторить поиск") {
                                    startSearch()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .padding(.horizontal, 60)
                            }
                        } else {
                            VStack(spacing: 20) {
                                Text("Найдено ламп: \(foundLights.count)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                        ForEach(foundLights) { light in
                                            HStack {
                                                Image(systemName: "lightbulb.fill")
                                                    .foregroundColor(.yellow)
                                                
                                                VStack(alignment: .leading) {
                                                    Text(light.metadata.name)
                                                        .foregroundColor(.white)
                                                    Text(light.id)
                                                        .font(.caption)
                                                        .foregroundColor(.white.opacity(0.6))
                                                }
                                                
                                                Spacer()
                                                
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                            .padding()
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(12)
                                        }
                                    }
                                    .padding()
                                }
                                
                                Button("Готово") {
                                    // Обновляем список ламп
                                    appViewModel.lightsViewModel.loadLights()
                                    dismiss()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .padding(.horizontal, 60)
                            }
                        }
                    } else {
                        // Начальный экран
                        VStack(spacing: 20) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            
                            Text("Готовы к поиску ламп?")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Button("Начать поиск") {
                                startSearch()
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.horizontal, 60)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Поиск в сети")
            .navigationBarItems(
                leading: Button("Отмена") {
                    dismiss()
                }
            )
        }
        .onAppear {
            startSearch()
        }
    }
    
    private func startSearch() {
        isSearching = true
        searchCompleted = false
        foundLights = []
        
        // ИСПРАВЛЕНИЕ: Используем простой loadLights() вместо сложного searchForNewLights()
        // Это тот же API вызов, но без искусственных задержек
        print("🔍 Запускаем поиск ламп через loadLights()...")
        
        appViewModel.lightsViewModel.loadLights()
        
        // Сразу помечаем поиск как завершенный и показываем текущие лампы
        DispatchQueue.main.async {
            self.isSearching = false
            self.searchCompleted = true
            self.foundLights = appViewModel.lightsViewModel.lights
            print("✅ Поиск завершен, найдено ламп: \(self.foundLights.count)")
        }
    }
}

/// Детальный экран управления лампой
struct LightDetailView: View {
    let light: Light
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var isOn: Bool
    @State private var brightness: Double
    @State private var selectedColor: Color = .white
    
    init(light: Light) {
        self.light = light
        self._isOn = State(initialValue: light.on.on)
        self._brightness = State(initialValue: light.dimming?.brightness ?? 100)
    }
    
    var lightsViewModel: LightsViewModel {
        appViewModel.lightsViewModel
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.1, blue: 0.2)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Переключатель
                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .scaleEffect(1.5)
                        .onChange(of: isOn) { _ in
                            lightsViewModel.toggleLight(light)
                        }
                    
                    // Яркость
                    if light.dimming != nil {
                        VStack(alignment: .leading) {
                            Text("Яркость: \(Int(brightness))%")
                                .foregroundColor(.white)
                            
                            Slider(value: $brightness, in: 1...100, step: 1)
                                .accentColor(.yellow)
                                .onChange(of: brightness) { _ in
                                    lightsViewModel.setBrightness(for: light, brightness: brightness)
                                }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Цвет (если поддерживается)
                    if light.color != nil {
                        ColorPicker("Цвет", selection: $selectedColor)
                            .onChange(of: selectedColor) { _ in
                                lightsViewModel.setColor(for: light, color: selectedColor)
                            }
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(light.metadata.name)
            .navigationBarItems(
                trailing: Button("Готово") {
                    dismiss()
                }
            )
        }
    }
}

// Стили кнопок из OnboardingView для консистентности
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

