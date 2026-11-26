import PhotosUI
import SwiftUI
import UIKit

@MainActor
struct HomeView: View {
    let appVersion: String
    /// Asks the parent to present the camera; it outlives this screen.
    let onOpenCamera: () -> Void
    let onPhoto: (PhotoInput) -> Void
    let onOpenSettings: () -> Void

    @Environment(LanguageManager.self) private var lang
    @State private var pickerItem: PhotosPickerItem?

    /// False in the simulator and on devices without a camera.
    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("🍙")
                .font(.system(size: 88))
                .padding(.bottom, 20)

            Text("Yumoji")
                .font(YumojiTheme.rounded(40, weight: .bold))
                .foregroundStyle(YumojiTheme.ink)

            Text(lang.t("home.tagline"))
                .font(YumojiTheme.rounded(15))
                .foregroundStyle(YumojiTheme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onOpenCamera()
                } label: {
                    actionLabel(lang.t("home.take_photo"), systemImage: "camera.fill", filled: true)
                }
                .disabled(!cameraAvailable)
                .opacity(cameraAvailable ? 1 : 0.45)

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    actionLabel(lang.t("home.pick_from_library"), systemImage: "photo.on.rectangle", filled: false)
                }

                if !cameraAvailable {
                    Text(lang.t("home.camera_unavailable"))
                        .font(YumojiTheme.rounded(12))
                        .foregroundStyle(YumojiTheme.inkSoft)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 12)

            Button(action: onOpenSettings) {
                Text(lang.t("home.version", appVersion))
                    .font(.system(size: 12))
                    .foregroundStyle(YumojiTheme.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(lang.t("home.version_accessibility", appVersion))
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YumojiTheme.cream.ignoresSafeArea())
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            pickerItem = nil
            onPhoto(.library(newItem))
        }
    }

    private func actionLabel(_ title: String, systemImage: String, filled: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(YumojiTheme.rounded(17, weight: .semibold))
            .foregroundStyle(filled ? Color.white : YumojiTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                filled ? YumojiTheme.accent : YumojiTheme.card,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
    }
}
