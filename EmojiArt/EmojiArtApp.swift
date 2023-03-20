//
//  EmojiArtApp.swift
//  EmojiArt
//
//  Created by Alex on 15.03.23.
//

import SwiftUI

@main
struct EmojiArtApp: App {
    let document = EmojiArtDocument()
    
    var body: some Scene {
        WindowGroup {
            EmojiArtDocumentView(document: document)
        }
    }
}
