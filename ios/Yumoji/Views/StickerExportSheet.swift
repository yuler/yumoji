import CoreGraphics
import SwiftUI
import UIKit

/// Export & share preview sheet with transparent or colored 1:1 backgrounds.
@MainActor
struct StickerExportSheet: View {
    let stickerImage: UIImage
    var saver: any StickerLibrarySaving = PhotoLibraryStickerSaver()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(LanguageManager.self) private var lang
    @Environment(ExportPaletteStore.self) private var palette

    @State private var pickerColor: Color = ExportBackgroundPresets.warm[0].color
    @State private var draftPickedColor: RGBAColor?
    @State private var suppressPickerSync = false
    @State private var isSaving = false
    @State private var savedSignature: String?
    @State private var alert: ExportSaveAlert?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    previewCard
                    paletteSection
                    actionButtons
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(YumojiTheme.cream.ignoresSafeArea())
            .navigationTitle(lang.t("export.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(YumojiTheme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("export.done")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(YumojiTheme.accent)
        .onAppear {
            if let current = palette.selected.solidColor {
                suppressPickerSync = true
                pickerColor = current.color
                suppressPickerSync = false
            }
        }
        .onChange(of: pickerColor) { _, newColor in
            guard !suppressPickerSync else { return }
            let picked = RGBAColor(color: newColor)
            draftPickedColor = palette.applyPickedColor(picked, replacing: draftPickedColor)
            savedSignature = nil
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

    // MARK: - Preview

    private var previewCard: some View {
        VStack(spacing: 10) {
            ZStack {
                if let solid = palette.selected.solidColor {
                    solid.color
                } else {
                    CheckerboardView()
                }

                Image(uiImage: stickerImage)
                    .resizable()
                    .scaledToFit()
                    .padding(26)
                    .shadow(
                        color: palette.selected.isTransparent ? YumojiTheme.shadow : .clear,
                        radius: 8,
                        y: 4
                    )
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: horizontalSizeClass == .regular ? 320 : 280)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(YumojiTheme.ink.opacity(0.08), lineWidth: 1)
            )

            Text(
                palette.selected.isTransparent
                    ? lang.t("export.format.transparent")
                    : lang.t("export.format.square")
            )
            .font(YumojiTheme.rounded(12, weight: .medium))
            .foregroundStyle(YumojiTheme.inkSoft)
        }
    }

    // MARK: - Background Palette

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(lang.t("export.background.label"))
                    .font(YumojiTheme.rounded(14, weight: .semibold))
                    .foregroundStyle(YumojiTheme.ink)
                Spacer()
                if !palette.customColors.isEmpty {
                    Text(lang.t("export.background.custom.hint"))
                        .font(YumojiTheme.rounded(11))
                        .foregroundStyle(YumojiTheme.inkSoft)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    transparentSwatch

                    ForEach(ExportBackgroundPresets.all, id: \.hexString) { swatch in
                        colorSwatch(swatch, removable: false)
                    }

                    ForEach(palette.customColors, id: \.hexString) { swatch in
                        colorSwatch(swatch, removable: true)
                    }

                    customColorPickerButton
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(YumojiTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var transparentSwatch: some View {
        let isSelected = palette.selected.isTransparent
        return Button {
            draftPickedColor = nil
            palette.select(.transparent)
            savedSignature = nil
        } label: {
            VStack(spacing: 5) {
                CheckerboardView(squareSize: 7)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(selectionRing(isSelected: isSelected))
                Text(lang.t("export.background.transparent"))
                    .font(YumojiTheme.rounded(11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? YumojiTheme.accent : YumojiTheme.inkSoft)
            }
        }
        .buttonStyle(.plain)
    }

    private func colorSwatch(_ swatch: RGBAColor, removable: Bool) -> some View {
        let isSelected = palette.selected.solidColor?.hexString == swatch.hexString
        return Button {
            draftPickedColor = nil
            palette.select(.solid(swatch))
            suppressPickerSync = true
            pickerColor = swatch.color
            suppressPickerSync = false
            savedSignature = nil
        } label: {
            VStack(spacing: 5) {
                Circle()
                    .fill(swatch.color)
                    .frame(width: 40, height: 40)
                    .overlay(selectionRing(isSelected: isSelected))
                Text(removable ? lang.t("export.background.custom") : " ")
                    .font(YumojiTheme.rounded(11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? YumojiTheme.accent : YumojiTheme.inkSoft)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if removable {
                Button(role: .destructive) {
                    if draftPickedColor?.hexString == swatch.hexString {
                        draftPickedColor = nil
                    }
                    palette.removeCustomColor(swatch)
                    savedSignature = nil
                } label: {
                    Label(lang.t("export.background.remove"), systemImage: "trash")
                }
            }
        }
    }

    private var customColorPickerButton: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                            center: .center
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(YumojiTheme.ink.opacity(0.14), lineWidth: 1)
                    )

                ColorPicker("", selection: $pickerColor, supportsOpacity: false)
                    .labelsHidden()
                    .scaleEffect(1.35)
                    .opacity(0.02)
            }
            .frame(width: 40, height: 40)

            Text(lang.t("export.background.custom"))
                .font(YumojiTheme.rounded(11))
                .foregroundStyle(YumojiTheme.inkSoft)
        }
    }

    private func selectionRing(isSelected: Bool) -> some View {
        Circle()
            .strokeBorder(
                isSelected ? YumojiTheme.accent : YumojiTheme.ink.opacity(0.14),
                lineWidth: isSelected ? 3 : 1
            )
    }

    // MARK: - Actions

    private var renderedCGImage: CGImage? {
        guard let cg = stickerImage.cgImage else { return nil }
        return StickerExportRenderer.render(cg, background: palette.selected)
    }

    private var currentSignature: String {
        switch palette.selected {
        case .transparent: return "transparent"
        case .solid(let c): return c.hexString
        }
    }

    private var isSavedForCurrentSelection: Bool {
        savedSignature == currentSignature
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Task { await saveToPhotos() }
            } label: {
                exportLabel(
                    isSavedForCurrentSelection ? lang.t("result.downloaded") : lang.t("result.download"),
                    systemImage: isSavedForCurrentSelection ? "checkmark" : "square.and.arrow.down",
                    filled: true,
                    showsProgress: isSaving
                )
            }
            .disabled(isSaving)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            if let rendered = renderedCGImage {
                ShareLink(
                    item: StickerPNGFile(image: rendered),
                    preview: SharePreview(
                        lang.t("result.share.preview"),
                        image: Image(uiImage: UIImage(cgImage: rendered))
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
    }

    private func saveToPhotos() async {
        guard !isSaving else { return }
        guard let rendered = renderedCGImage, let data = StickerPNG.data(from: rendered) else {
            alert = .failed
            return
        }
        let signature = currentSignature
        isSaving = true
        defer { isSaving = false }
        do {
            try await saver.savePNG(data)
            savedSignature = signature
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
                .minimumScaleFactor(0.75)
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

private enum ExportSaveAlert: Identifiable {
    case denied
    case failed

    var id: String {
        switch self {
        case .denied: "denied"
        case .failed: "failed"
        }
    }
}

/// Subtle light/dark checkerboard indicating transparency in the export preview.
private struct CheckerboardView: View {
    var squareSize: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            let light = YumojiTheme.card
            let dark = YumojiTheme.surfaceSecondary
            for row in 0..<rows {
                for col in 0..<cols {
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color((row + col).isMultiple(of: 2) ? light : dark))
                }
            }
        }
    }
}
