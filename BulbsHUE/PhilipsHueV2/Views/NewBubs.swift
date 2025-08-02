import SwiftUI

struct NewBulbConnectView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Фоновый градиент с эффектами размытия
            backgroundGradient
            
            VStack(spacing: 0) {
                // Верхняя часть с заголовком и кнопкой закрытия
                headerSection
                    .padding(.top, 50)
                
                // Иконка лампочки
                bulbIcon
                    .padding(.top, 60)
                
                // Важная информация
                importantSection
                    .padding(.top, 40)
                
                Spacer()
                
                // Кнопки действий
                actionButtons
                    .padding(.bottom, 50)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            // Основной темный фон
            Color(red: 0.03, green: 0.03, blue: 0.03)
            
            // Размытые эллипсы для создания градиента
            Group {
                // Синий эллипс справа сверху
                Ellipse()
                    .fill(Color(red: 0.08, green: 0, blue: 1))
                    .frame(width: 265, height: 381)
                    .offset(x: 128, y: -255.50)
                    .blur(radius: 287.30)
                
                // Бирюзовый эллипс слева сверху
                Ellipse()
                    .fill(Color(red: 0, green: 1, blue: 0.92))
                    .frame(width: 268, height: 290)
                    .offset(x: -91.50, y: -320)
                    .blur(radius: 287.30)
                
                // Зеленый эллипс по центру
                Ellipse()
                    .fill(Color(red: 0.08, green: 1, blue: 0))
                    .frame(width: 268, height: 52)
                    .offset(x: 5.50, y: -239)
                    .blur(radius: 158)
                
                // Голубой эллипс справа
                Ellipse()
                    .fill(Color(red: 0, green: 0.43, blue: 1))
                    .frame(width: 531.25, height: 52)
                    .offset(x: 336.81, y: -137)
                    .blur(radius: 158)
                
                // Светло-бирюзовый эллипс справа
                Ellipse()
                    .fill(Color(red: 0, green: 1, blue: 0.53))
                    .frame(width: 531.25, height: 52)
                    .offset(x: 366.81, y: -241)
                    .blur(radius: 158)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            Text("NEW BULB")
                .font(.custom("DM Sans", size: 20).weight(.thin))
                .tracking(3.40)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
            
            Spacer()
            
            // Кнопка закрытия
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .stroke(Color(red: 0.79, green: 1, blue: 1), lineWidth: 1)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                }
            }
        }
        .padding(.horizontal, 47)
    }
    
    // MARK: - Bulb Icon
    
    private var bulbIcon: some View {
        ZStack {
            // Лучи вокруг лампочки
            ForEach(0..<8) { index in
                Rectangle()
                    .fill(Color(red: 0.79, green: 1, blue: 1))
                    .frame(width: 2, height: 20)
                    .offset(y: -70)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            
            // Иконка лампочки
            Image(systemName: "lightbulb")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
        }
    }
    
    // MARK: - Important Section
    
    private var importantSection: some View {
        VStack(spacing: 16) {
            Text("IMPORTANT")
                .font(.custom("DM Sans", size: 14).weight(.bold))
                .tracking(2.10)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
            
            Text("MAKE SURE THE LIGHTS\nAND SMART PLUGS YOU WANT TO ADD\nARE CONNECTED TO POWER")
                .font(.custom("DM Sans", size: 12).weight(.light))
                .tracking(1.80)
                .lineSpacing(16.80)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 24) {
            // Кнопка USE SERIAL NUMBER
            VStack(spacing: 8) {
                Button(action: {
                    // Действие для серийного номера
                }) {
                    ZStack {
                        // Фоновое свечение
                        RoundedRectangle(cornerRadius: 1000)
                            .fill(Color(red: 0.40, green: 0.49, blue: 0.68))
                            .frame(width: 244, height: 68)
                            .blur(radius: 89.10)
                            .offset(x: 12.80, y: 0)
                        
                        // Основная кнопка
                        RoundedRectangle(cornerRadius: 1000)
                            .stroke(Color(red: 0.79, green: 1, blue: 1).opacity(0.3), lineWidth: 0.5)
                            .frame(width: 280, height: 72)
                            .background(
                                RoundedRectangle(cornerRadius: 1000)
                                    .fill(Color.clear)
                            )
                        
                        Text("USE SERIAL NUMBER")
                            .font(.custom("DM Sans", size: 16).weight(.light))
                            .tracking(2.40)
                            .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                    }
                    .frame(width: 280, height: 72)
                }
                
                Text("ON THE LAMP OR LABEL")
                    .font(.custom("DM Sans", size: 10).weight(.light))
                    .tracking(1.50)
                    .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
            }
            
            // Разделитель OR
            Text("OR")
                .font(.custom("DM Sans", size: 16).weight(.light))
                .tracking(2.40)
                .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                .padding(.vertical, 8)
            
            // Кнопка SEARCH IN NETWORK
            Button(action: {
                // Действие для поиска в сети
            }) {
                ZStack {
                    // Фоновое свечение
                    RoundedRectangle(cornerRadius: 1000)
                        .fill(Color(red: 0.40, green: 0.49, blue: 0.68))
                        .frame(width: 244, height: 68)
                        .blur(radius: 89.10)
                        .offset(x: 10.80, y: 0)
                    
                    // Основная кнопка с зеленоватым оттенком
                    RoundedRectangle(cornerRadius: 1000)
                        .fill(Color(red: 0.28, green: 0.75, blue: 0.35).opacity(0.05))
                        .frame(width: 280, height: 72)
                    
                    RoundedRectangle(cornerRadius: 1000)
                        .fill(Color(red: 0.28, green: 0.75, blue: 0.35).opacity(0.05))
                        .frame(width: 272, height: 64)
                    
                    Text("SEARCH IN NETWORK")
                        .font(.custom("DM Sans", size: 16).weight(.light))
                        .tracking(2.40)
                        .foregroundColor(Color(red: 0.79, green: 1, blue: 1))
                }
                .frame(width: 280, height: 72)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NewBulbConnectView()
}
