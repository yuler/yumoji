import SwiftUI

@MainActor
struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    private var themeBinding: Binding<ThemeMode> {
        Binding(
            get: { themeManager.selection },
            set: { themeManager.selection = $0 }
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
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(YumojiTheme.cream, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
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
                Text("跟随系统")
                    .tag(ThemeMode.system)
                Text("浅色")
                    .tag(ThemeMode.light)
                Text("深色")
                    .tag(ThemeMode.dark)
            } label: {
                Text("外观")
                    .foregroundStyle(YumojiTheme.ink)
            }
            .pickerStyle(.menu)
            .tint(YumojiTheme.inkSoft)
        } header: {
            Text("通用")
                .foregroundStyle(YumojiTheme.inkSoft)
        }
        .listRowBackground(YumojiTheme.card)
    }
}
