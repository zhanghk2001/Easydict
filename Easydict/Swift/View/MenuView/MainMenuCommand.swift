//
//  MainMenuCommand.swift
//  Easydict
//
//  Created by Sharker on 2024/2/4.
//  Copyright © 2024 izual. All rights reserved.
//

import SwiftUI

struct EasydictMainMenu: Commands {
    // MARK: Internal

    var body: some Commands {
        // Shortcuts
        MainMenuShortcutCommand()

        // Override About
        CommandGroup(replacing: .appInfo) {
            Button {
                HostWindowManager.shared.showAboutWindow()
            } label: {
                Text("menubar.about")
            }
        }
    }
}
