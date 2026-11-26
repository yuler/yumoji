import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// Download and share for the current sticker. Shown once the cutout is ready.
@MainActor
struct StickerExportBar: View {
    let image: UIImage
    var saver: any StickerLibrarySaving

    @Environment(LanguageManager.self) private var lang

    @State private var isSaving = false
    @State private var savedImageID: ObjectIdentifier?
    @State private var alert: SaveAlert?

    init(image: UIImage, saver: any StickerLibrarySaving = PhotoLibraryStickerSaver()) {
        self.image = image
        self.saver = saver
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await save() }
            } label: {
                exportLabel(
                    isSaved ? lang.t("result.downloaded") : lang.t("result.download"),
                    systemImage: isSaved ? "checkmark" : "square.and.arrow.down",
                    filled: true,
                    showsProgress: isSaving
                )
            }
            .disabled(isSaving)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            if let data = pngData {
                ShareLink(
                    item: StickerPNGFile(data: data),
                    preview: SharePreview(
                        lang.t("result.share.preview"),
                        image: Image(uiImage: image)
                    )
                ) {
                    exportLabel(
                        lang.t("result.share"),
                        systemImage: "square.and.arrow.up",
                        filled: false,
                        showsProgress: false
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .alert(item: $alert) { current in
            switch current {
            case .denied:
                Alert(
                    title: Text(lang.t("result.save.denied.title")),
                    message: Text(lang.t("result.save.denied.message")),
                    primaryButton: .default(Text(lang.t("result.save.denied.settings"))) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel(Text(lang.t("result.save.dismiss")))
                )
            case .failed:
                Alert(
                    title: Text(lang.t("result.save.failed.title")),
                    message: Text(lang.t("result.save.failed.message")),
                    dismissButton: .default(Text(lang.t("result.save.dismiss")))
                )
            }
        }
    }

    private var isSaved: Bool {
        savedImageID == ObjectIdentifier(image)
    }

    private var pngData: Data? {
        guard let cgImage = image.cgImage else { return nil }
        return StickerPNG.data(from: cgImage)
    }

    private func save() async {
        guard !isSaving else { return }
        guard let data = pngData else {
            alert = .failed
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await saver.savePNG(data)
            savedImageID = ObjectIdentifier(image)
        } catch StickerSaveError.denied {
            alert = .denied
        } catch {
            alert = .failed
        }
    }

    private func exportLabel(
        _ title: String,
        systemImage: String,
        filled: Bool,
        showsProgress: Bool
    ) -> some View {
        HStack(spacing: 6) {
            if showsProgress {
                ProgressView()
                    .tint(filled ? Color.white : YumojiTheme.accent)
            } else {
                Image(systemName: systemImage)
            }
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(YumojiTheme.rounded(16, weight: .semibold))
        .foregroundStyle(filled ? Color.white : YumojiTheme.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            filled ? YumojiTheme.accent : YumojiTheme.card,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

private enum SaveAlert: Identifiable {
    case denied
    case failed

    var id: String {
        switch self {
        case .denied: "denied"
        case .failed: "failed"
        }
    }
}

/// A sticker PNG handed to the system share sheet, named `Yumoji.png`.
struct StickerPNGFile: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { item in
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("Yumoji.png")
            try item.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
