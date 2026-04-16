//
//  Laconical_PortApp.swift
//  Laconical Port
//
//  Created by Daniel on 15/04/2026.
//

import SwiftUI

@main
struct Laconical_PortApp: App {
    init() {
        MediaLibraryService().ensureImportsFolderExists()
    }

    var body: some Scene {
        WindowGroup {
            LaconicalPlayerRootView()
        }
    }
}
