import Darwin
import Foundation

struct ThumbnailCacheStats: Sendable {
    var requests: Int = 0
    var hits: Int = 0
    var misses: Int = 0
    var trackedEntries: Int = 0
}

struct LibraryPerformanceSnapshot: Sendable {
    var firstPaintSeconds: Double?
    var fullIndexSeconds: Double?
    var indexedCount: Int
    var memoryMB: Double?
    var thumbnailStats: ThumbnailCacheStats

    static let empty = LibraryPerformanceSnapshot(
        firstPaintSeconds: nil,
        fullIndexSeconds: nil,
        indexedCount: 0,
        memoryMB: nil,
        thumbnailStats: ThumbnailCacheStats()
    )
}

enum ProcessMemory {
    static func residentMemoryMB() -> Double? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    intPtr,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let bytes = Double(info.resident_size)
        return bytes / 1_048_576.0
    }
}
