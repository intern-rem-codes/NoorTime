//
//  NoorTimeApp.swift
//  NoorTime
//
//  Created by Intern on 24/04/2026.
//

import SwiftUI

@main
struct NoorTimeApp: App {
    init() {
        ArabicTypography.registerFontIfNeeded()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
