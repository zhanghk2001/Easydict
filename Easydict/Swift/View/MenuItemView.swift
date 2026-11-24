//
//  MenuItemView.swift
//  Easydict
//
//  Created by Kyle on 2023/12/29.
//  Copyright © 2023 izual. All rights reserved.
//

import SettingsAccess
import SFSafeSymbols
import SwiftUI

struct MenuItemView: View {
    var body: some View {
        Group {
            menuItem(.selectTranslate).keyboardShortcut(.selectTranslate)
            menuItem(.snipTranslate).keyboardShortcut(.snipTranslate)

            Divider()

            settingItem.keyboardShortcut(.init(","))
            quitItem.keyboardShortcut(.init("q"))
        }
    }

    private func menuItem(_ action: ShortcutAction) -> some View {
        Button {
            action.executeAction()
        } label: {
            Label {
                Text(LocalizedStringKey(action.localizedStringKey()))
            } icon: {
                Image(systemSymbol: action.icon)
            }
        }
    }

    /// Settings item
    @ViewBuilder private var settingItem: some View {
        let titleKey = LocalizedStringKey("Settings...")
        if #available(macOS 14.0, *) {
            SettingsLink {
                Text(titleKey)
            } preAction: {
                logInfo("Open App Settings")
                NSApplication.shared.activateApp()
            } postAction: {
                // nothing to do
            }
        } else {
            Button(titleKey) {
                logInfo("Open App Settings")
                NSApplication.shared.activateApp()

                // Refer https://stackoverflow.com/a/77265223/8378840
                NSApplication.shared.sendAction(
                    Selector(("showSettingsWindow:")), to: nil, from: nil
                )
            }
        }
    }

    /// Quit item
    @ViewBuilder private var quitItem: some View {
        Button("quit") {
            logInfo("Quit Application")
            NSApplication.shared.terminate(nil)
        }
    }
}
