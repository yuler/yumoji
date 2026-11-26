import Foundation

/// Short synthesized clips for the cut. Generated in code so the app doesn't
/// ship a binary asset for two UI sounds.
enum StageWAV {
    static let sampleRate = 22_050

    /// Two or three paper snips, about the length of the scissor pass.
    static func paperCut() -> Data {
        var previous: Float = 0
        var noise = SplitMix(state: 0xC0FFEE)
        let samples = render(seconds: 0.38) { time in
            let white = noise.next()
            let high = white - previous
            previous = white
            let envelope = burst(time, center: 0.05, width: 0.035)
                + burst(time, center: 0.16, width: 0.04)
                + burst(time, center: 0.28, width: 0.045)
            return high * envelope * 0.8
        }
        return encode(samples)
    }

    /// A soft thud for the paper landing.
    static func dong() -> Data {
        let samples = render(seconds: 0.32) { time in
            let body = sin(2 * .pi * 168 * time) * exp(-time * 7)
            let knock = sin(2 * .pi * 82 * time) * exp(-time * 16)
            return Float(body * 0.7 + knock * 0.3)
        }
        return encode(samples)
    }

    private static func burst(_ time: Double, center: Double, width: Double) -> Float {
        let x = (time - center) / width
        return Float(exp(-x * x * 6))
    }

    private static func render(seconds: Double, sample: (Double) -> Float) -> [Int16] {
        let count = Int((seconds * Double(sampleRate)).rounded())
        var raw = [Float](repeating: 0, count: count)
        var peak: Float = 0.0001
        for index in 0..<count {
            let value = sample(Double(index) / Double(sampleRate))
            raw[index] = value
            peak = max(peak, abs(value))
        }
        let gain = min(1, 0.9 / peak)
        return raw.map { Int16(clamping: Int((Float($0) * gain * 32_767).rounded())) }
    }

    private static func encode(_ samples: [Int16]) -> Data {
        let dataSize = samples.count * 2
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLE(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.appendLE(UInt32(16))
        data.appendLE(UInt16(1))
        data.appendLE(UInt16(1))
        data.appendLE(UInt32(sampleRate))
        data.appendLE(UInt32(sampleRate * 2))
        data.appendLE(UInt16(2))
        data.appendLE(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        data.appendLE(UInt32(dataSize))
        for sample in samples {
            data.appendLE(UInt16(bitPattern: sample))
        }
        return data
    }
}

private struct SplitMix {
    var state: UInt64

    mutating func next() -> Float {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Float(z & 0xFFFF) / 32_767.5 - 1
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { bytes in
            append(contentsOf: bytes)
        }
    }
}
