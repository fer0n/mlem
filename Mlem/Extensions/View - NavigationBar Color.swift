//
//  View - View - NavigationBar Color.swift
//  Mlem
//
//  Created by fer0n on 11.08.23.
//

import SwiftUI

struct NavigationBarColorModifier: ViewModifier {
    @AppStorage("hasTranslucentInsets") var hasTranslucentInsets: Bool = true

    func body(content: Content) -> some View {
        if hasTranslucentInsets {
            content
        } else {
            content
                .toolbarBackground(Color.systemBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

extension View {
    func navigationBarColor() -> some View {
        self.modifier(NavigationBarColorModifier())
    }
}
