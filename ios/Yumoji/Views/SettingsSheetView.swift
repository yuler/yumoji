import SwiftData
import SwiftUI
import UIKit

@MainActor
struct SettingsSheetView: View {
    let appVersion: String
    let installChannel: InstallChannel
    var updateChecker: AppUpdateChecker = AppUpdateChecker()
    var onClearedStickers: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var lang
    @Environment(SoundEffects.self) private var sound

    @State private var isChecking = false
    @State private var checkResult: AppUpdate.CheckResult?
    @State private var storageStats: StickerStorageStats = .empty
    @State private var showClearConfirm = false

    private var themeBinding: Binding<ThemeMode> {
        Binding(
            get: { themeManager.selection },
            set: { themeManager.selection = $0 }
        )
    }

    private var soundBinding: Binding<Bool> {
        Binding(
            get: { sound.isEnabled },
            set: { sound.isEnabled = $0 }
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
                storageSection
                aboutSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(YumojiTheme.cream.ignoresSafeArea())
            .navigationTitle(lang.t("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(YumojiTheme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
        .onAppear {
            refreshStorageStats()
        }
        .confirmationDialog(
            lang.t("settings.storage.clear.title"),
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button(lang.t("settings.storage.clear.confirm"), role: .destructive) {
                clearAllStickers()
            }
            Button(lang.t("settings.storage.clear.cancel"), role: .cancel) {}
        } message: {
            Text(lang.t("settings.storage.clear.message", storageStats.count))
        }
    }

    private var generalSection: some View {
        Section {
            HStack(spacing: 12) {
                Text(lang.t("settings.appearance"))
                    .foregroundStyle(YumojiTheme.ink)
                    .lineLimit(1)
                    .layoutPriority(1)
                    .accessibilityHidden(true)
                Picker(selection: themeBinding) {
                    Text(lang.t("settings.appearance.system"))
                        .tag(ThemeMode.system)
                    Text(lang.t("settings.appearance.light"))
                        .tag(ThemeMode.light)
                    Text(lang.t("settings.appearance.dark"))
                        .tag(ThemeMode.dark)
                } label: {
                    Text(lang.t("settings.appearance"))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel(lang.t("settings.appearance"))
                .frame(maxWidth: .infinity)
            }
            .id(lang.resolved)

            Toggle(isOn: soundBinding) {
                Text(lang.t("settings.sound"))
                    .foregroundStyle(YumojiTheme.ink)
            }
            .tint(YumojiTheme.accent)

            Picker(selection: languageBinding) {
                Text(lang.t("settings.language.system"))
                    .tag(AppLanguage.system)
                Text("简体中文")
                    .tag(AppLanguage.zhHans)
                Text("English")
                    .tag(AppLanguage.english)
                Text("日本語")
                    .tag(AppLanguage.japanese)
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

    private var storageSection: some View {
        Section {
            LabeledContent {
                Text(lang.t("settings.storage.count.value", storageStats.count))
                    .foregroundStyle(YumojiTheme.inkSoft)
                    .monospacedDigit()
            } label: {
                Text(lang.t("settings.storage.count.label"))
                    .foregroundStyle(YumojiTheme.ink)
            }

            LabeledContent {
                Text(formattedStorageSize)
                    .foregroundStyle(YumojiTheme.inkSoft)
                    .monospacedDigit()
            } label: {
                Text(lang.t("settings.storage.size.label"))
                    .foregroundStyle(YumojiTheme.ink)
            }

            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Text(lang.t("settings.storage.clear"))
            }
            .disabled(storageStats.count == 0)
        } header: {
            Text(lang.t("settings.section.storage"))
                .foregroundStyle(YumojiTheme.inkSoft)
        } footer: {
            Text(lang.t("settings.storage.footer"))
                .foregroundStyle(YumojiTheme.inkSoft)
        }
        .listRowBackground(YumojiTheme.card)
    }

    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(appVersion)
                    .foregroundStyle(YumojiTheme.inkSoft)
                    .monospacedDigit()
            } label: {
                Text(lang.t("settings.version.label"))
                    .foregroundStyle(YumojiTheme.ink)
            }

            Button {
                Task { await checkForUpdate() }
            } label: {
                HStack {
                    Text(isChecking ? lang.t("settings.update.checking") : lang.t("settings.update.check"))
                        .foregroundStyle(YumojiTheme.accent)
                    Spacer()
                    if isChecking {
                        ProgressView()
                            .tint(YumojiTheme.accent)
                    }
                }
            }
            .disabled(isChecking)

            if case .available(_, let url) = checkResult {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    HStack {
                        Text(
                            installChannel == .appStore
                                ? lang.t("settings.update.open_app_store")
                                : lang.t("settings.update.open_testflight")
                        )
                        .fontWeight(.medium)
                        .foregroundStyle(YumojiTheme.accent)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(YumojiTheme.accent)
                    }
                }
            }
        } header: {
            Text(lang.t("settings.section.about"))
                .foregroundStyle(YumojiTheme.inkSoft)
        } footer: {
            if let footerText = updateStatusFooter {
                Text(footerText)
                    .foregroundStyle(YumojiTheme.inkSoft)
            }
        }
        .listRowBackground(YumojiTheme.card)
    }

    private var formattedStorageSize: String {
        ByteCountFormatter.string(fromByteCount: storageStats.totalBytes, countStyle: .file)
    }

    private var updateStatusFooter: String? {
        guard let checkResult else { return nil }
        switch checkResult {
        case .upToDate:
            return lang.t("settings.update.up_to_date")
        case .failed:
            return lang.t("settings.update.failed")
        case .storeLinkMissing(let version):
            return lang.t("settings.update.store_link_missing", version)
        case .available(let version, _):
            return lang.t("settings.update.available", version)
        }
    }

    private func refreshStorageStats() {
        storageStats = StickerStorage.stats(in: modelContext)
    }

    private func clearAllStickers() {
        try? StickerStorage.deleteAll(in: modelContext)
        refreshStorageStats()
        onClearedStickers()
    }

    private func checkForUpdate() async {
        isChecking = true
        checkResult = await updateChecker.check(currentVersion: appVersion, channel: installChannel)
        isChecking = false
    }
}
