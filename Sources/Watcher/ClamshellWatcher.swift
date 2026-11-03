import Foundation
import IOKit

/// フタの開閉を監視し、「開 → 閉」の遷移だけを通知する。
final class ClamshellWatcher {
    private let onClosed: () -> Void
    private var notifyPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var root: io_service_t = 0
    private var wasClosed: Bool

    init(onClosed: @escaping () -> Void) {
        self.onClosed = onClosed
        self.wasClosed = Self.lidClosed()
    }

    /// true = フタが閉じている。ノートでない機種ではキー自体が無く false になる。
    static func lidClosed() -> Bool {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("IOPMrootDomain")
        )
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        let property = IORegistryEntryCreateCFProperty(
            service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0
        )
        return (property?.takeRetainedValue() as? Bool) ?? false
    }

    func start() {
        root = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("IOPMrootDomain")
        )
        guard root != 0 else {
            NSLog("[SleepToggle] IOPMrootDomain を取得できませんでした")
            return
        }

        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let port = notifyPort else { return }
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)

        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceInterestCallback = { refcon, _, _, _ in
            guard let refcon else { return }
            Unmanaged<ClamshellWatcher>.fromOpaque(refcon)
                .takeUnretainedValue()
                .handleChange()
        }

        let result = IOServiceAddInterestNotification(
            port, root, "IOGeneralInterest", callback, context, &notifier
        )
        if result != KERN_SUCCESS {
            NSLog("[SleepToggle] 通知登録に失敗しました: %d", result)
        }
    }

    private func handleChange() {
        // kIOPMMessageClamshellStateChange はマクロで Swift に入ってこない。
        // メッセージ種別を判定せず、毎回 registry を読み直して遷移だけを見る。
        let closed = Self.lidClosed()
        defer { wasClosed = closed }
        guard closed, !wasClosed else { return }
        onClosed()
    }
}
