import CuaDriverCore
import Foundation

public struct ImageCoordinateContext: Sendable {
    /// Scale from delivered screenshot x pixels back to native capture pixels.
    public let scaleX: Double
    /// Scale from delivered screenshot y pixels back to native capture pixels.
    public let scaleY: Double
    /// Pixels-per-point factor used by the capture.
    public let backingScaleFactor: Double
    /// Window id that produced this screenshot, when known.
    public let windowId: UInt32?
    /// Exact window frame that produced the screenshot.
    public let windowBounds: WindowBounds?

    public init(
        scaleX: Double,
        scaleY: Double,
        backingScaleFactor: Double,
        windowId: UInt32? = nil,
        windowBounds: WindowBounds?
    ) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.backingScaleFactor = backingScaleFactor
        self.windowId = windowId
        self.windowBounds = windowBounds
    }

    public func withWindowId(_ windowId: UInt32?) -> ImageCoordinateContext {
        ImageCoordinateContext(
            scaleX: scaleX,
            scaleY: scaleY,
            backingScaleFactor: backingScaleFactor,
            windowId: windowId ?? self.windowId,
            windowBounds: windowBounds
        )
    }
}

/// Per-pid zoom context: the native-pixel origin of the last zoom crop
/// and the resize ratio, so the click tool can map zoom-image pixels
/// back to the resized-image coordinate space automatically.
public struct ZoomContext: Sendable {
    /// Top-left of the crop in original (native) pixels.
    public let originX: Int
    public let originY: Int
    /// Size of the crop in original (native) pixels.
    public let width: Int
    public let height: Int
    /// The resize ratio (original / resized). Divide native pixels by
    /// this to get resized-image pixels.
    public let ratio: Double
    public let backingScaleFactor: Double
    public let windowBounds: WindowBounds?
}

/// Tracks per-pid image resize ratios and last-zoom context so the
/// click tool can map coordinates from any source automatically.
public actor ImageResizeRegistry {
    public static let shared = ImageResizeRegistry()
    private var ratios: [Int32: Double] = [:]
    private var latestContextsByPid: [Int32: ImageCoordinateContext] = [:]
    private var contextsByWindow: [WindowKey: ImageCoordinateContext] = [:]
    private var zooms: [Int32: ZoomContext] = [:]

    private struct WindowKey: Hashable {
        let pid: Int32
        let windowId: UInt32
    }

    public func setContext(
        _ context: ImageCoordinateContext,
        forPid pid: Int32,
        windowId: UInt32?
    ) {
        let storedContext = context.withWindowId(windowId)
        latestContextsByPid[pid] = storedContext
        ratios[pid] = storedContext.scaleX
        if let windowId {
            contextsByWindow[WindowKey(pid: pid, windowId: windowId)] = storedContext
        }
    }

    public func context(forPid pid: Int32, windowId: UInt32?) -> ImageCoordinateContext? {
        if let windowId {
            if let context = contextsByWindow[WindowKey(pid: pid, windowId: windowId)] {
                return context
            }
            let latest = latestContextsByPid[pid]
            return latest?.windowId == nil || latest?.windowId == windowId ? latest : nil
        }
        return latestContextsByPid[pid]
    }

    /// Record the scale-up ratio for a pid.
    public func setRatio(_ ratio: Double, forPid pid: Int32) {
        ratios[pid] = ratio
        latestContextsByPid[pid] = ImageCoordinateContext(
            scaleX: ratio,
            scaleY: ratio,
            backingScaleFactor: 1.0,
            windowId: nil,
            windowBounds: nil
        )
    }

    /// Clear the ratio for a pid (no resize happened).
    public func clearRatio(forPid pid: Int32) {
        ratios.removeValue(forKey: pid)
        latestContextsByPid.removeValue(forKey: pid)
        contextsByWindow = contextsByWindow.filter { $0.key.pid != pid }
    }

    /// Returns the scale-up ratio, or nil if no resize is active.
    public func ratio(forPid pid: Int32) -> Double? {
        ratios[pid]
    }

    /// Record the last zoom crop for a pid.
    public func setZoom(_ context: ZoomContext, forPid pid: Int32) {
        zooms[pid] = context
    }

    /// Clear the zoom context for a pid.
    public func clearZoom(forPid pid: Int32) {
        zooms.removeValue(forKey: pid)
    }

    /// Returns the last zoom context, or nil.
    public func zoom(forPid pid: Int32) -> ZoomContext? {
        zooms[pid]
    }
}
