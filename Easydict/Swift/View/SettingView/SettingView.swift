//
//  SettingView.swift
//  Easydict
//
//  Created by Kyle on 2023/12/29.
//  Copyright © 2023 izual. All rights reserved.
//

import Defaults
import SwiftUI

// MARK: - SettingTab

enum SettingTab: Int {
    case general
    case service
    case disabled
    case shortcut
    case about
}

// MARK: - SettingView

struct SettingView: View {
    // MARK: Internal

    var body: some View {
        TabView(selection: $selection) {
            TranslationPreferencesTab()
                .tabItem { Label("setting_general", systemImage: "gear") }
                .tag(SettingTab.general)

            ServiceTab()
                .tabItem { Label("service", systemImage: "briefcase") }
                .tag(SettingTab.service)

            DisabledAppTab()
                .tabItem { Label("disabled_app_list", systemImage: "nosign") }
                .tag(SettingTab.disabled)

            ShortcutTab()
                .tabItem { Label("shortcut", systemImage: "command.square") }
                .tag(SettingTab.shortcut)

            AboutTab()
                .tabItem { Label("setting.about", systemImage: "info.bubble") }
                .tag(SettingTab.about)
        }
        .background(
            WindowAccessor(window: $window.didSet(execute: { _ in
                // reset frame when first launch
                resizeWindowFrame()
            }))
        )
        .onChange(of: selection) { _ in
            resizeWindowFrame()
        }
    }

    func resizeWindowFrame() {
        guard let window else { return }

        // Disable zoom button, refer: https://stackoverflow.com/a/66039864/8378840
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        // Keep the settings page Windows all the same width to avoid strange animations.
        let height: Double = switch selection {
        case .disabled:
            500
        case .about:
            300
        default:
            defaultSettingsWindowHeight
        }

        let newSize = CGSize(width: settingsWindowWidth, height: height)

        let originalFrame = window.frame
        let newY = originalFrame.origin.y + originalFrame.size.height - newSize.height
        let newRect = NSRect(origin: CGPoint(x: originalFrame.origin.x, y: newY), size: newSize)

        window.setFrame(newRect, display: true, animate: false)
        // macOS 27: keep the sidebar below the title bar by removing the
        // `.fullSizeContentView` style SwiftUI keeps after resize. Older macOS
        // versions are unaffected.
        // Refer: https://github.com/tisfeng/Easydict/pull/1258#issuecomment-5186918247
        if #available(macOS 27.0, *) {
            window.styleMask.remove(.fullSizeContentView)
        }
        window.styleMask.remove(.resizable)
    }

    // MARK: Private

    @State private var selection = SettingTab.general
    @State private var window: NSWindow?

    private let settingsWindowWidth: Double = 960
    private let defaultSettingsWindowHeight: Double = 720
}

// MARK: - TranslationPreferencesTab

private struct TranslationPreferencesTab: View {
    @Default(.autoShowQueryIcon) private var autoShowQueryIcon
    @Default(.autoQuerySelectedText) private var autoQuerySelectedText
    @Default(.autoQueryOCRText) private var autoQueryOCRText
    @Default(.autoCopyFirstTranslatedText) private var autoCopyFirstTranslatedText

    var body: some View {
        Form {
            Section("setting.general.query_language.header") {
                FirstAndSecondLanguageSettingView()
            }

            Section("setting.general.auto_query.header") {
                Toggle("setting.advance.auto_show_query_icon", isOn: $autoShowQueryIcon)
                Toggle("auto_query_selected_text", isOn: $autoQuerySelectedText)
                Toggle("auto_query_ocr_text", isOn: $autoQueryOCRText)
                Toggle("auto_copy_first_translated_text", isOn: $autoCopyFirstTranslatedText)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingView()
}
