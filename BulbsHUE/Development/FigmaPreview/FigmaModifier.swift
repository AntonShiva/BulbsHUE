import SwiftUI

struct FigmaViewModifier: ViewModifier {
    enum ContentType {
        case url(URL)
        case image(Image)
        case figma(fileID: String, componentID: String)
    }

    enum Error: Swift.Error {
        case wrongFigmaURL(URL)
        case failToMakeImage(URL)
        case failToGetImageURL(String)
    }

    @State var contentType: ContentType
    @State var previewState: PreviewState
    @State private var isPanelVisible: Bool = true

    @State private var image: Image?
    @State private var opacity: Double = 0.5

    @State private var position: CGFloat = 0
    @State private var dragOffset: CGFloat = 0

    @State private var session: URLSession = .shared

    @Environment(\.figmaAccessToken) private var figmaAccessToken

    func body(content: Content) -> some View {
        GeometryReader { mainGeometry in
            ZStack(alignment: .top) {
                content
                    .frame(width: mainGeometry.size.width, height: mainGeometry.size.height)
                    
                if previewState != .hidden {
                    figmaImage(geometry: mainGeometry)
                        .frame(width: mainGeometry.size.width, height: mainGeometry.size.height)
                }
                
                VStack {
                    if isPanelVisible {
                        settingsPanel
                            .opacity(0.2)
                    }
                    Spacer()
                }
                
                // Кнопка поверх контента
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            isPanelVisible.toggle()
                        }
                    }) {
                        Image(systemName: isPanelVisible ? "chevron.up" : "chevron.down")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color(red: 0, green: 0, blue: 0).opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
            }
            .frame(width: mainGeometry.size.width, height: mainGeometry.size.height)
        }
        .ignoresSafeArea()
        .onChange(of: previewState) { 
            switch previewState {
            case .hidden:
                break
            case .layers:
                opacity = 0.5
            case .compare:
                opacity = 1
                position = 0
                dragOffset = 0
            }
        }
        .task {
            do {
                let image = try await image(for: contentType)
                await MainActor.run {
                    self.image = image
                }
            }
            catch {
                print(error)
            }
        }
    }

    private func image(for contentType: ContentType) async throws -> Image {
        switch contentType {
        case .url(let url):
            guard url.pathComponents.count >= 3 else {
                throw Error.wrongFigmaURL(url)
            }
            let fileID = url.pathComponents[2]
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw Error.wrongFigmaURL(url)
            }
            guard let queryItem = components.queryItems?.first(where: { $0.name == "node-id" }) else {
                throw Error.wrongFigmaURL(url)
            }
            guard let componentID = queryItem.value else {
                throw Error.wrongFigmaURL(url)
            }
            return try await image(for: fileID, componentID: componentID)
        case .image(let image):
            return image
        case .figma(let fileID, let componentID):
            return try await image(for: fileID, componentID: componentID)
        }
    }

    private var settingsPanel: some View {
        VStack {
            HStack {
                Picker("", selection: $previewState.animation()) {
                    ForEach(PreviewState.allCases, content: \.body)
                }
                .pickerStyle(.segmented)
            }
            if previewState == .layers {
                Slider(value: $opacity.animation(), in: 0...1)
                    .tint(Color(red: 0, green: 0, blue: 0))
            }
        }
        .padding()
        .background(Color.white)
    }

    private func figmaImage(geometry: GeometryProxy) -> some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(opacity)
                    .if(previewState == .compare) { image in
                        image
                            .mask(alignment: .leading) {
                                Rectangle()
                                    .frame(width: geometry.size.width / 2 + position + dragOffset)
                            }
                    }
                if previewState == .compare {
                    slideView(geometry: geometry)
                }
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
    }

    private func slideView(geometry: GeometryProxy) -> some View {
        ZStack {
            Image(systemName: "arrow.left.and.right")
                .frame(width: 40, height: 40)
                .background(Color.white)
                .opacity(0.01)
                .cornerRadius(20)
        }
        .fixedSize(horizontal: true, vertical: true)
        .offset(x: position + dragOffset)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    dragOffset = gesture.translation.width
                }
                .onEnded { gesture in
                    position += gesture.translation.width
                    dragOffset = 0
                }
        )
    }

    private func image(for fileID: String, componentID: String) async throws -> Image {
        let url = URL(string: "https://api.figma.com/v1/images/\(fileID)?ids=\(componentID)")!
        var request = URLRequest(url: url)
        request.setValue(figmaAccessToken, forHTTPHeaderField: "X-FIGMA-TOKEN")
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(FigmaResponse.self, from: data)
        let formattedComponentID = componentID.replacingOccurrences(of: "-", with: ":")
        guard let imageURL = response.images[formattedComponentID] else {
            throw Error.failToGetImageURL(formattedComponentID)
        }
        let (imageData, _) = try await session.data(from: imageURL)
        guard let image = UIImage(data: imageData) else {
            throw Error.failToMakeImage(imageURL)
        }
        return Image(uiImage: image)
    }
}

extension PreviewState: View, Identifiable {
    public var id: Self { self }

    public var body: some View {
        switch self {
        case .hidden:
            Image(systemName: "eye.slash")
        case .layers:
            Image(systemName: "square.3.layers.3d.down.right")
        case .compare:
            Image(systemName: "slider.horizontal.below.square.and.square.filled")
        }
    }
}

private struct FigmaResponse: Decodable {
    let err: String?
    let images: [String: URL]
}

private extension View {
    @ViewBuilder
    func `if`<T>(_ condition: Bool, transform: (Self) -> T) -> some View where T : View {
        if condition {
            transform(self)
        }
        else {
            self
        }
    }
}
