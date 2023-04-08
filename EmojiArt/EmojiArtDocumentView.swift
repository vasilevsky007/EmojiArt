//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Alex on 15.03.23.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    @State private var selectedEmojis: Set<EmojiArtModel.Emoji> = []

    let defaultEmojiFontSize: CGFloat = 40
    
    private var somethingSelected: Bool {
        !selectedEmojis.isEmpty
    }
    
    private func isSelected(_ emoji: EmojiArtModel.Emoji) -> CGFloat {
        if selectedEmojis.index(matching: emoji) != nil {
            return 1
        } else {
            return 0
        }
    }
    
    
   
    
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            PaletteChooser(emojiFontSize: defaultEmojiFontSize, selectedEmojis: $selectedEmojis, deleter: document.deleteEmoji)
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
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(5)
                }
                ForEach(document.emojis) { emoji in
                    if  selectedEmojis.index(matching: emoji) != nil {
                        RoundedRectangle(cornerRadius: fontSize(for: emoji) * 0.15)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                            .frame(width: fontSize(for: emoji) * 1.1, height: fontSize(for: emoji) * 1.1)
                            .scaleEffect(zoomScale * gestureEmojiScale)
                            .position(position(for: emoji, in: geometry))
                    }
                    Text(emoji.text)
                        .font(.system(size: fontSize(for: emoji)))
                        .scaleEffect(zoomScale * (isSelected(emoji) == 1 ? gestureEmojiScale : 1))
                        .position(position(for: emoji, in: geometry))
                        .gesture(singleEmojiMoveGesture(emoji).exclusively(before: tapToSelect(emoji)))
                }
            }.clipped()
            //TODO: refactor to dropDestination
            .onDrop(of: [.plainText, .url, .image], isTargeted: nil) { providers, location in
                return drop(providers: providers, at: location, in: geometry)
            }
            .gesture(zoomGesture().simultaneously(with: someDragGesture()).exclusively(before: tapToSelect(nil)))
            .alert(item: $alertToShow) { alertToShow in
                // return Alert
                alertToShow.alert()
            }
            .onChange(of: document.backgroundImageFetchStatus) { status in
                switch status {
                case .failed(let url):
                    showBackgroundImageFetchFailedAlert(url)
                default:
                    break
                }
            }
        }
    }
    
    // L12 state which says whether a certain identifiable alert should be showing
    @State private var alertToShow: IdentifiableAlert?
    
    // L12 sets alertToShow to an IdentifiableAlert explaining a url fetch failure
    private func showBackgroundImageFetchFailedAlert(_ url: URL) {
        alertToShow = IdentifiableAlert(id: "fetch failed: " + url.absoluteString, alert: {
            Alert(
                title: Text("Background Image Fetch"),
                message: Text("Couldn't load image from \(url)."),
                dismissButton: .default(Text("OK"))
            )
        })
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
        return convertFromEmojiCoordinaets(
            (emoji.x + Int(gestureMoveOffset.width * isSelected(emoji)) + Int(emoji.id == singleMoveState.emoji?.id ? singleMoveState.moveOffset.width : 0),
             emoji.y + Int(gestureMoveOffset.height * isSelected(emoji)) + Int(emoji.id == singleMoveState.emoji?.id ? singleMoveState.moveOffset.height : 0)),
            in: geometry)
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
    
    @GestureState private var gestureEmojiScale: CGFloat = 1

    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    
    @GestureState private var gestureMoveOffset: CGSize = CGSize.zero
    
    private struct SingleEmojiMoveState {
        var emoji: EmojiArtModel.Emoji?
        var moveOffset: CGSize
    }
    
    @GestureState private var singleMoveState = SingleEmojiMoveState(emoji: nil, moveOffset: CGSize.zero)
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale*gestureZoomScale
    }
    
    private func singleEmojiMoveGesture(_ emoji: EmojiArtModel.Emoji) -> some Gesture {
        return DragGesture()
            .updating($singleMoveState) { latestDragGestureValue, singleMoveState, _ in
                singleMoveState.emoji = emoji
                singleMoveState.moveOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                document.moveEmoji(emoji, by: finalDragGestureValue.translation / zoomScale)
            }
    }
    
    private func zoomGesture() -> some Gesture {
        if somethingSelected {
            return MagnificationGesture()
                .updating($gestureEmojiScale, body: { latestGestureScale, ourGestireStateInOut, transaction in
                    ourGestireStateInOut = latestGestureScale
                })
                .onEnded { gestureScaleAtTheEnd in
                    for emoji in selectedEmojis {
                        document.scaleEmoji(emoji, by: gestureScaleAtTheEnd)
                    }
                }
        }
        else {
            return MagnificationGesture()
                .updating($gestureZoomScale, body: { latestGestureScale, ourGestireStateInOut, transaction in
                    ourGestireStateInOut = latestGestureScale
                })
                .onEnded { gestureScaleAtTheEnd in
                    steadyStateZoomScale *= gestureScaleAtTheEnd
                }
        }
    }
    
    private func someDragGesture() -> some Gesture {
        if somethingSelected {
            return moveGesture()
        } else {
            return panGesture()
        }
    }
    
    private func panGesture() -> _EndedGesture<GestureStateGesture<DragGesture, CGSize>> {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffsetInOut , _ in
                gesturePanOffsetInOut = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + finalDragGestureValue.translation / zoomScale
            }
    }
    
    private func moveGesture() -> _EndedGesture<GestureStateGesture<DragGesture, CGSize>> {
        DragGesture()
            .updating($gestureMoveOffset) { latestDragValue, gestureMoveOffset, _ in
                gestureMoveOffset = latestDragValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                print("finaldrag ",finalDragGestureValue.translation, selectedEmojis, "\n\n")
                for emoji in selectedEmojis {
                    document.moveEmoji(emoji, by: finalDragGestureValue.translation / zoomScale)
                }
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
    
    private func tapToSelect(_ emoji: EmojiArtModel.Emoji?) -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                if let emoji = emoji{
                    if let index = selectedEmojis.index(matching: emoji){
                        selectedEmojis.remove(at: index)
                    } else {
                        selectedEmojis.update(with: emoji)
                    }
                }
                else {
                    selectedEmojis.removeAll()
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
}








































struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
            .previewDevice("iPad Pro (11-inch) (4th generation)")
    }
}
