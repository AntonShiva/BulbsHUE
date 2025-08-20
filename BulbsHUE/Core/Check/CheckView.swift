import SwiftUI

struct CheckView: View {
    var isActive: Bool
    
    var body: some View {
        ZStack {
            Rectangle()
              .foregroundColor(.clear)
              .frame(width: 48, height: 48)
              .background(.white)
              .cornerRadius(9)
              .opacity(0.1)
            
            if isActive {
                Image("check")
            }
        }
    }
}

struct CheckView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CheckView(isActive: true)
            CheckView(isActive: false)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
