import CoreGraphics
import Foundation

/// One point on a traced outline, with the direction of travel in radians.
struct ContourSample: Equatable {
    var point: CGPoint
    var angle: CGFloat
}

/// Outline of the largest subject in a mask, in the mask's pixel space.
/// People and food share this path: whatever the mask already decided.
enum ContourPath {
    /// - Parameters:
    ///   - maxSide: Long side of the coarse grid the walk runs on.
    /// - Returns: Boundary points in mask pixels, or empty when nothing qualifies.
    static func trace(
        width: Int,
        height: Int,
        pixels: [UInt8],
        threshold: UInt8 = SubjectMask.threshold,
        maxSide: Int = 140
    ) -> [CGPoint] {
        guard width > 0, height > 0, pixels.count == width * height, maxSide > 0 else { return [] }

        let scale = max(1, Int((Double(max(width, height)) / Double(maxSide)).rounded(.up)))
        let columns = (width + scale - 1) / scale
        let rows = (height + scale - 1) / scale
        var grid = [Bool](repeating: false, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let x = min(width - 1, column * scale + scale / 2)
                let y = min(height - 1, row * scale + scale / 2)
                grid[row * columns + column] = pixels[y * width + x] >= threshold
            }
        }

        guard let cells = largestComponent(grid, columns: columns) else { return [] }
        let loop = walk(cells: cells, columns: columns).map { cell in
            CGPoint(
                x: min(CGFloat(width - 1), (CGFloat(cell.x) + 0.5) * CGFloat(scale)),
                y: min(CGFloat(height - 1), (CGFloat(cell.y) + 0.5) * CGFloat(scale))
            )
        }
        return smooth(loop)
    }

    /// Point and tangent at `progress` (0...1) along a closed outline.
    static func sample(points: [CGPoint], progress: CGFloat) -> ContourSample? {
        guard let first = points.first else { return nil }
        guard points.count >= 2 else { return ContourSample(point: first, angle: 0) }

        var closed = points
        if first != points[points.count - 1] {
            closed.append(first)
        }

        var lengths = [CGFloat](repeating: 0, count: closed.count)
        for index in 1..<closed.count {
            let previous = closed[index - 1]
            let current = closed[index]
            lengths[index] = lengths[index - 1] + hypot(current.x - previous.x, current.y - previous.y)
        }
        let total = lengths[lengths.count - 1]
        guard total > 0 else { return ContourSample(point: first, angle: 0) }

        let target = min(max(progress, 0), 1) * total
        var index = 1
        while index < lengths.count - 1 && lengths[index] < target {
            index += 1
        }
        let span = lengths[index] - lengths[index - 1]
        let local = span > 0 ? (target - lengths[index - 1]) / span : 0
        let start = closed[index - 1]
        let end = closed[index]
        return ContourSample(
            point: CGPoint(
                x: start.x + (end.x - start.x) * local,
                y: start.y + (end.y - start.y) * local
            ),
            angle: atan2(end.y - start.y, end.x - start.x)
        )
    }

    // MARK: - Grid

    private static func largestComponent(_ grid: [Bool], columns: Int) -> Set<Int>? {
        var seen = [Bool](repeating: false, count: grid.count)
        var best: [Int] = []
        let steps = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        for start in grid.indices where grid[start] && !seen[start] {
            var stack = [start]
            var cells: [Int] = []
            seen[start] = true
            while let current = stack.popLast() {
                cells.append(current)
                let x = current % columns
                let y = current / columns
                for step in steps {
                    let nextX = x + step.0
                    let nextY = y + step.1
                    guard nextX >= 0, nextY >= 0, nextX < columns else { continue }
                    let next = nextY * columns + nextX
                    guard next < grid.count, grid[next], !seen[next] else { continue }
                    seen[next] = true
                    stack.append(next)
                }
            }
            if cells.count > best.count {
                best = cells
            }
        }
        return best.isEmpty ? nil : Set(best)
    }

    /// Moore neighborhood walk. Stops the first time it returns to the start.
    private static func walk(cells: Set<Int>, columns: Int) -> [(x: Int, y: Int)] {
        guard let startIndex = cells.min(by: { lhs, rhs in
            let leftRow = lhs / columns
            let rightRow = rhs / columns
            if leftRow != rightRow { return leftRow < rightRow }
            return lhs % columns < rhs % columns
        }) else { return [] }

        let neighbors = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]
        let start = (x: startIndex % columns, y: startIndex / columns)
        var points = [start]
        var current = start
        var back = (x: start.x - 1, y: start.y)

        for _ in 0..<(cells.count * 2 + 8) {
            let incoming = neighbors.firstIndex { $0.0 == back.x - current.x && $0.1 == back.y - current.y } ?? 0
            var next: (x: Int, y: Int)?
            for step in 1...neighbors.count {
                let neighbor = neighbors[(incoming + step) % neighbors.count]
                let x = current.x + neighbor.0
                let y = current.y + neighbor.1
                guard x >= 0, y >= 0, x < columns, cells.contains(y * columns + x) else { continue }
                next = (x, y)
                break
            }
            guard let found = next else { break }
            if found == start { break }
            points.append(found)
            back = current
            current = found
        }
        return points
    }

    /// One pass so the scissors rides a curve instead of the coarse grid's stairs.
    private static func smooth(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 4 else { return points }
        return points.indices.map { index in
            let previous = points[(index - 1 + points.count) % points.count]
            let current = points[index]
            let next = points[(index + 1) % points.count]
            return CGPoint(
                x: (previous.x + current.x * 2 + next.x) / 4,
                y: (previous.y + current.y * 2 + next.y) / 4
            )
        }
    }
}
