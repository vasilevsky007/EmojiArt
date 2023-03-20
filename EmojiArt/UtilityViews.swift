//
//  UtilityViews.swift
//  EmojiArt
//
//  Created by Alex on 20.03.23.
//

import SwiftUI

struct OptionalImage: View {
    var uiImage: UIImage?
    
    var body: some View {
        if uiImage != nil {
            Image (uiImage: uiImage!)
        }
    }
}
