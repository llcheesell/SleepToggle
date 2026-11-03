import AppKit

/// 設定画面の「試聴」用。実際の再生は監視エージェントが行う。
@MainActor
enum LidWarningSound {
    /// 再生中に解放されると途中で止まるので保持しておく。
    private static var current: NSSound?

    static func play() {
        guard let url = Bundle.main.url(forResource: "LidWarning", withExtension: "wav"),
              let sound = NSSound(contentsOf: url, byReference: false) else { return }
        sound.volume = 0.6
        current = sound
        sound.play()
    }
}
