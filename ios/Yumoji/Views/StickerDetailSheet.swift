import SwiftUI
import UIKit

/// Lightweight preview sheet opened when tapping a sticker in the home waterfall grid.
@MainActor
struct StickerDetailSheet: View {
    let record: StickerRecord
    let onViewOnBoard: (UUID) -> Void
    let onExport: (UIImage) -> Void
    let onDelete: (StickerRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lang

    @State private var fullImage: UIImage?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                previewStage

                metadataRow

                actionButtons

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(YumojiTheme.cream.ignoresSafeArea())
            .navigationTitle(lang.t("detail.title"))
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
        .task(id: record.id) {
            fullImage = StickerThumbnailCache.shared.fullResolutionImage(for: record)
        }
        .confirmationDialog(
            lang.t("board.delete.confirm.title"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(lang.t("board.delete.confirm.action"), role: .destructive) {
                dismiss()
                onDelete(record)
            }
            Button(lang.t("board.delete.confirm.cancel"), role: .cancel) {}
        }
    }

    private var previewStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(YumojiTheme.stage)

            if let image = fullImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .shadow(color: YumojiTheme.shadow.opacity(0.9), radius: 14, y: 6)
            } else {
                ProgressView()
                    .tint(YumojiTheme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }

    private var metadataRow: some View {
        HStack(spacing: 12) {
            Label(formattedDate, systemImage: "calendar")
                .font(YumojiTheme.rounded(13, weight: .medium))
                .foregroundStyle(YumojiTheme.inkSoft)

            Spacer()

            if record.pixelWidth > 0, record.pixelHeight > 0 {
                Text("\(record.pixelWidth) × \(record.pixelHeight)")
                    .font(YumojiTheme.rounded(12, weight: .medium))
                    .foregroundStyle(YumojiTheme.inkSoft)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 4)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                let image = fullImage ?? StickerThumbnailCache.shared.fullResolutionImage(for: record)
                dismiss()
                if let image {
                    onExport(image)
                }
            } label: {
                Label(lang.t("board.action.export"), systemImage: "square.and.arrow.up")
                    .font(YumojiTheme.rounded(16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(YumojiTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    let id = record.id
                    dismiss()
                    onViewOnBoard(id)
                } label: {
                    Label(lang.t("detail.view_on_board"), systemImage: "square.grid.2x2")
                        .font(YumojiTheme.rounded(15, weight: .semibold))
                        .foregroundStyle(YumojiTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(YumojiTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(YumojiTheme.ink.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    showDeleteConfirm = true
                } label: {
                    Label(lang.t("board.action.delete"), systemImage: "trash")
                        .font(YumojiTheme.rounded(15, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = lang.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: record.effectiveDate)
    }
}
