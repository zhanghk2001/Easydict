//
//  MainMenuShortcutCommand.swift
//  Easydict
//
//  Created by Sharker on 2024/2/4.
//  Copyright © 2024 izual. All rights reserved.
//

import SwiftUI

extension EasydictMainMenu {
    struct MainMenuShortcutCommand: Commands {
        // MARK: Internal

        var body: some Commands {
            // shortcut Commands
            CommandMenu("shortcut") {
                ForEach(appShortcutCommandList) { item in
                    MainMenuShortcutCommandItem(dataItem: item)
                }
            }
        }

        // MARK: Private

        private let appShortcutCommandList = ShortcutAction.appActions.map {
            MainMenuShortcutCommandDataItem(action: $0)
        }
    }
}
