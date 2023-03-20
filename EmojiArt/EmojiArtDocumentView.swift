//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Alex on 15.03.23.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    let defaultEmojiFontSize: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            palette
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            ZStack{
                Color.white.overlay {
                    OptionalImage(uiImage: document.backgroundImage)
                        .scaleEffect(zoomScale)
                        .position(convertFromEmojiCoordinaets((0, 0), in: geometry))
                }
                .gesture(doubleTapToZoom(in: geometry.size))
                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView().scaleEffect(2)
                }
                ForEach(document.emojis) { emoji in
                    Text(emoji.text)
                        .font(.system(size: fontSize(for: emoji)))
                        .scaleEffect(zoomScale)
                        .position(position(for: emoji, in: geometry))
                }
            }.clipped()
            //TODO: refactor to dropDestination
            .onDrop(of: [.plainText, .url, .image], isTargeted: nil) { providers, location in
                return drop(providers: providers, at: location, in: geometry)
            }
            .gesture(zoomGesture().simultaneously(with: panGesture()))
        }
    }
    
    private func drop (providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        var found = providers.loadObjects(ofType: URL.self) { url in
            document.setBackground(EmojiArtModel.Background.url(url.imageURL))
        }
        if !found {
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1) {
                    document.setBackground(.imageData(data))
                }
            }
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinaets(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale)
                }
            }
        }
        return found
    }
    
    private func fontSize(for emoji: EmojiArtModel.Emoji) ->CGFloat {
        return CGFloat(emoji.size)
    }
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) ->CGPoint {
        return convertFromEmojiCoordinaets((emoji.x, emoji.y), in: geometry)
    }
    
    private func convertFromEmojiCoordinaets(_ location: (x: Int, y: Int), in geometry: GeometryProxy) ->CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + panOffset.height)
    }
    
    private func convertToEmojiCoordinaets(_ location: CGPoint, in geometry: GeometryProxy) -> (x: Int, y: Int) {
        let center = geometry.frame(in: .local).center
        let location = CGPoint (
            x: location.x - panOffset.width - center.x / zoomScale,
            y: location.y - panOffset.height - center.y / zoomScale
        )
        return (Int(location.x),  Int(location.y))
    }
    
    @State private var steadyStateZoomScale: CGFloat = 1
    
    @GestureState private var gestureZoomScale: CGFloat = 1

    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale*gestureZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale, body: { latestGestureScale, ourGestireStateInOut, transaction in
                ourGestireStateInOut = latestGestureScale
            })
            .onEnded { gestureScaleAtTheEnd in
                steadyStateZoomScale *= gestureScaleAtTheEnd
            }
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffsetInOut , _ in
                gesturePanOffsetInOut = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + finalDragGestureValue.translation / zoomScale
            }
    }
    
    private func doubleTapToZoom (in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit (_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 {
            let hZoom =  size.width / image.size.width
            let vZoom =  size.height / image.size.height
            steadyStateZoomScale =  min(hZoom, vZoom)
            steadyStatePanOffset = .zero
        }
    }
    
    var palette: some View {
        ScrollingEmojiView(emojis: testEmojis).font(.system(size: defaultEmojiFontSize))
    }
    
    let testEmojis = "🤓🍠🍎🌨️🌱🦂🐦👜🐸⚽️🚗🚁🛸🚫⛔️⚠️✅➕🏳️"
    
    struct ScrollingEmojiView: View {
        let emojis: String
        var body: some View {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(emojis.map { String($0) }, id: \.self) { emoji in
                        Text(emoji)
                            .onDrag { //TODO: refactor to new draggable(_:)
                                NSItemProvider(object: emoji as NSString)
                            }
                    }
                }
            }
        }
    }
}








































struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}
