import PhotosUI
import SwiftUI
import UIKit

@MainActor
struct HomeView: View {
    /// Asks the parent to present the camera; it outlives this screen.
    let onOpenCamera: () -> Void
    let onPhoto: (PhotoInput) -> Void

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

            Text("把每一口好吃的，收成一枚贴纸")
                .font(YumojiTheme.rounded(15))
                .foregroundStyle(YumojiTheme.inkSoft)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onOpenCamera()
                } label: {
                    actionLabel("拍一张", systemImage: "camera.fill", filled: true)
                }
                .disabled(!cameraAvailable)
                .opacity(cameraAvailable ? 1 : 0.45)

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    actionLabel("从相册选一张", systemImage: "photo.on.rectangle", filled: false)
                }

                if !cameraAvailable {
                    Text("这台设备没有可用的相机，请从相册选择")
                        .font(YumojiTheme.rounded(12))
                        .foregroundStyle(YumojiTheme.inkSoft)
                }
            }
            .padding(.bottom, 28)
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
