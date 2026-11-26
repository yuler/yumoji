import SwiftUI

@MainActor
struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var lang

    private var themeBinding: Binding<ThemeMode> {
        Binding(
            get: { themeManager.selection },
            set: { themeManager.selection = $0 }
        )
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { lang.selection },
            set: { lang.selection = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                generalSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(YumojiTheme.cream.ignoresSafeArea())
            .navigationTitle(lang.t("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(YumojiTheme.cream, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("settings.done")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(YumojiTheme.accent)
    }

    private var generalSection: some View {
        Section {
            Picker(selection: themeBinding) {
                Text(lang.t("settings.appearance.system"))
                    .tag(ThemeMode.system)
                Text(lang.t("settings.appearance.light"))
                    .tag(ThemeMode.light)
                Text(lang.t("settings.appearance.dark"))
                    .tag(ThemeMode.dark)
            } label: {
                Text(lang.t("settings.appearance"))
                    .foregroundStyle(YumojiTheme.ink)
            }
            .pickerStyle(.menu)
            .tint(YumojiTheme.inkSoft)
            .id(lang.resolved)

            Picker(selection: languageBinding) {
                Text(lang.t("settings.language.system"))
                    .tag(AppLanguage.system)
                Text("简体中文")
                    .tag(AppLanguage.zhHans)
                Text("English")
                    .tag(AppLanguage.english)
            } label: {
                Text(lang.t("settings.language"))
                    .foregroundStyle(YumojiTheme.ink)
            }
            .pickerStyle(.menu)
            .tint(YumojiTheme.inkSoft)
            .id(lang.resolved)
        } header: {
            Text(lang.t("settings.section.general"))
                .foregroundStyle(YumojiTheme.inkSoft)
        }
        .listRowBackground(YumojiTheme.card)
    }
}
