import AVFoundation

/// Plays the cut's paper snip and the landing thud. Call only when sound is enabled.
@MainActor
final class StageSoundPlayer {
    private var paper: AVAudioPlayer?
    private var dong: AVAudioPlayer?
    private var ready = false

    func prepare() {
        guard !ready else { return }
        ready = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        paper = try? AVAudioPlayer(data: StageWAV.paperCut())
        dong = try? AVAudioPlayer(data: StageWAV.dong())
        paper?.volume = 0.9
        dong?.volume = 0.85
        paper?.prepareToPlay()
        dong?.prepareToPlay()
    }

    func playPaperCut() {
        prepare()
        paper?.currentTime = 0
        paper?.play()
    }

    func playDong() {
        prepare()
        dong?.currentTime = 0
        dong?.play()
    }
}
