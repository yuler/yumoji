import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// Where a photo came from.
enum PhotoInput {
    case camera(UIImage)
    case library(PhotosPickerItem)
    case dropped(Data)
}

enum CutoutFailure: Equatable {
    case unreadablePhoto
    case composeFailed
    case message(String)
}

enum CutoutState: Equatable {
    case working
    case ready
    case noSubject
    case failed(CutoutFailure)
}

/// One photo-to-sticker run: decodes the photo, lifts the foreground subject,
/// and composes a white-bordered transparent sticker ready for preview or saving.
@Observable
@MainActor
final class StickerSession {
    private(set) var isActive = false
    private(set) var cutout: CutoutState = .working
    private(set) var sticker: UIImage?
    /// The decoded photo, kept so the stage can show it while the cutout runs.
    private(set) var photoImage: UIImage?
    /// EXIF capture date for library photos, or shutter time for camera photos.
    private(set) var capturedAt: Date?
    /// Where the sticker canvas sits in the photo, in photo pixels.
    private(set) var stickerCrop: PixelRect?
    /// Subject outline in photo pixels. Empty until the cutout is ready.
    private(set) var subjectContour: [CGPoint] = []
    /// Photo with the subject punched out, aligned with `photoImage`.
    private(set) var outsideMask: UIImage?
    /// Long side of the detected subject in pixels; 0 until the cutout is done.
    private(set) var subjectLongSide = 0

    var style = StickerStyle()

    private let lifter: any SubjectLifting

    @ObservationIgnored private var photo: CGImage?
    @ObservationIgnored private var mask: SubjectMask?
    @ObservationIgnored private var pipelineTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var isRendering = false
    @ObservationIgnored private var renderPending = false

    init(lifter: any SubjectLifting = VisionSubjectLifter()) {
        self.lifter = lifter
    }

    func start(_ input: PhotoInput) {
        reset()
        isActive = true
        pipelineTask = Task {
            await self.run(input)
        }
    }

    /// Drops the current photo and cancels whatever is still running.
    func reset() {
        pipelineTask?.cancel()
        pipelineTask = nil
        generation += 1
        photo = nil
        mask = nil
        sticker = nil
        photoImage = nil
        capturedAt = nil
        stickerCrop = nil
        subjectContour = []
        outsideMask = nil
        subjectLongSide = 0
        cutout = .working
        isActive = false
    }

    /// Re-renders the sticker from the mask already computed. Call after `style` changes.
    func styleDidChange() {
        requestRender()
    }

    // MARK: - Pipeline

    private func run(_ input: PhotoInput) async {
        let decoded = await loadPhoto(input)
        guard !Task.isCancelled else { return }
        guard let loaded = decoded else {
            cutout = .failed(.unreadablePhoto)
            return
        }

        photo = loaded.image
        photoImage = UIImage(cgImage: loaded.image)
        capturedAt = loaded.capturedAt

        do {
            let lifted = try await lifter.liftSubject(from: loaded.image)
            guard !Task.isCancelled else { return }
            guard let bounds = lifted.bounds else {
                throw SubjectLiftingError.noSubject
            }
            mask = lifted
            subjectLongSide = max(bounds.width, bounds.height)
            requestRender()
        } catch SubjectLiftingError.noSubject {
            guard !Task.isCancelled else { return }
            cutout = .noSubject
        } catch {
            guard !Task.isCancelled else { return }
            cutout = .failed(.message(error.localizedDescription))
        }
    }

    private func loadPhoto(_ input: PhotoInput) async -> DecodedPhoto? {
        switch input {
        case .camera(let image):
            let now = Date()
            return await Task.detached(priority: .userInitiated) {
                guard let decoded = PhotoLoader.decode(image) else { return nil }
                return DecodedPhoto(image: decoded, capturedAt: now)
            }.value
        case .library(let item):
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                return nil
            }
            return await Task.detached(priority: .userInitiated) {
                PhotoLoader.decodeWithMetadata(data)
            }.value
        case .dropped(let data):
            return await Task.detached(priority: .userInitiated) {
                PhotoLoader.decodeWithMetadata(data)
            }.value
        }
    }

    // MARK: - Rendering

    /// Renders off the main thread, one at a time. Requests that arrive while a
    /// render is running collapse into a single follow-up with the latest style.
    private func requestRender() {
        renderPending = true
        guard !isRendering else { return }
        isRendering = true
        Task {
            await self.renderLoop()
        }
    }

    private func renderLoop() async {
        while renderPending {
            renderPending = false
            guard let currentPhoto = photo, let currentMask = mask else { break }
            let currentStyle = style
            let token = generation

            let rendered = await Task.detached(priority: .userInitiated) {
                RenderedCutout.make(image: currentPhoto, mask: currentMask, style: currentStyle)
            }.value

            guard token == generation else { continue }
            if let stickerImage = rendered.sticker, let bounds = currentMask.bounds {
                stickerCrop = StickerCompositor.cropRect(subject: bounds, style: currentStyle)
                sticker = UIImage(cgImage: stickerImage)
                subjectContour = rendered.contour
                if let bitmap = rendered.outside, let image = bitmap.cgImage() {
                    outsideMask = UIImage(cgImage: image)
                } else {
                    outsideMask = nil
                }
                cutout = .ready
            } else if sticker == nil {
                cutout = .failed(.composeFailed)
            }
        }
        isRendering = false
    }
}
