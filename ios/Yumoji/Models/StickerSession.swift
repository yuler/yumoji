import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// Where a photo came from.
enum PhotoInput {
    case camera(UIImage)
    case library(PhotosPickerItem)
}

enum CutoutState: Equatable {
    case working
    case ready
    case noSubject
    case failed(String)
}

enum AnalysisState: Equatable {
    case loading
    case loaded(FoodAnalysis)
    case failed
}

/// One photo-to-sticker run: decodes the photo, then runs the cutout and the
/// analysis side by side. Nothing is persisted.
@Observable
@MainActor
final class StickerSession {
    private(set) var isActive = false
    private(set) var cutout: CutoutState = .working
    private(set) var analysis: AnalysisState = .loading
    private(set) var sticker: UIImage?
    /// The decoded photo, kept so the stage can show it while the cutout runs.
    private(set) var photoImage: UIImage?
    /// Where the sticker canvas sits in the photo, in photo pixels.
    private(set) var stickerCrop: PixelRect?
    /// Long side of the detected subject in pixels; 0 until the cutout is done.
    private(set) var subjectLongSide = 0

    var style = StickerStyle()
    /// Debug switch: makes the next analysis fail so the `待识别` state can be seen.
    var simulateAnalysisFailure = false

    private let lifter: any SubjectLifting
    private let analyzer: any FoodAnalyzing

    @ObservationIgnored private var photo: CGImage?
    @ObservationIgnored private var mask: SubjectMask?
    @ObservationIgnored private var pipelineTask: Task<Void, Never>?
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var isRendering = false
    @ObservationIgnored private var renderPending = false

    init(
        lifter: any SubjectLifting = VisionSubjectLifter(),
        analyzer: any FoodAnalyzing = MockFoodAnalyzer()
    ) {
        self.lifter = lifter
        self.analyzer = analyzer
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
        analysisTask?.cancel()
        analysisTask = nil
        generation += 1
        photo = nil
        mask = nil
        sticker = nil
        photoImage = nil
        stickerCrop = nil
        subjectLongSide = 0
        cutout = .working
        analysis = .loading
        isActive = false
    }

    func retryAnalysis() {
        startAnalysis()
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
            cutout = .failed("这张照片读不出来")
            return
        }

        photo = loaded
        photoImage = UIImage(cgImage: loaded)
        startAnalysis()

        do {
            let lifted = try await lifter.liftSubject(from: loaded)
            guard !Task.isCancelled else { return }
            guard let bounds = lifted.bounds else {
                throw SubjectLiftingError.noSubject
            }
            mask = lifted
            subjectLongSide = max(bounds.width, bounds.height)
            requestRender()
        } catch SubjectLiftingError.noSubject {
            guard !Task.isCancelled else { return }
            analysisTask?.cancel()
            cutout = .noSubject
        } catch {
            guard !Task.isCancelled else { return }
            analysisTask?.cancel()
            cutout = .failed(error.localizedDescription)
        }
    }

    private func loadPhoto(_ input: PhotoInput) async -> CGImage? {
        switch input {
        case .camera(let image):
            return await Task.detached(priority: .userInitiated) {
                PhotoLoader.decode(image)
            }.value
        case .library(let item):
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                return nil
            }
            return await Task.detached(priority: .userInitiated) {
                PhotoLoader.decode(data)
            }.value
        }
    }

    // MARK: - Analysis

    private func startAnalysis() {
        analysisTask?.cancel()
        guard let currentPhoto = photo else { return }
        analysis = .loading
        let shouldFail = simulateAnalysisFailure
        analysisTask = Task {
            do {
                let result = try await self.analyzer.analyze(currentPhoto)
                guard !Task.isCancelled else { return }
                if shouldFail {
                    throw FoodAnalysisError.unavailable
                }
                self.analysis = .loaded(result)
            } catch {
                guard !Task.isCancelled else { return }
                self.analysis = .failed
            }
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
                StickerCompositor.makeSticker(image: currentPhoto, mask: currentMask, style: currentStyle)
            }.value

            guard token == generation else { continue }
            if let rendered, let bounds = currentMask.bounds {
                stickerCrop = StickerCompositor.cropRect(subject: bounds, style: currentStyle)
                sticker = UIImage(cgImage: rendered)
                cutout = .ready
            } else if sticker == nil {
                cutout = .failed("贴纸合成失败")
            }
        }
        isRendering = false
    }
}
