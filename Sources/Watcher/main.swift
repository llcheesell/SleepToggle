import AppKit
import Foundation
import os

let log = Logger(subsystem: "com.llcheesell.SleepToggle", category: "watcher")

/// 警告音の場所。実行ファイルは SleepToggle.app/Contents/MacOS/ にあるので
/// 隣の Resources を直接見る（tool の Bundle.main に頼らない）。
let lidWarningURL: URL = {
    let exe = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
    return exe.resolvingSymlinksInPath()
        .deletingLastPathComponent()          // MacOS
        .deletingLastPathComponent()          // Contents
        .appendingPathComponent("Resources/LidWarning.wav")
}()

/// 鳴らしている最中に解放されると途中で止まるため保持しておく。
var currentSound: NSSound?

/// フタを閉じたときの警告音。システムのアラート音は警告として強すぎるので同梱のチャイムを使う。
func playLidWarning() {
    guard let sound = NSSound(contentsOf: lidWarningURL, byReference: false) else {
        log.error("警告音を読み込めません: \(lidWarningURL.path, privacy: .public)")
        return
    }
    sound.volume = 0.6
    currentSound = sound
    sound.play()
}

if CommandLine.arguments.contains("--test-sound") {
    playLidWarning()
    Thread.sleep(forTimeInterval: 1.6)
    exit(0)
}

if CommandLine.arguments.contains("--status") {
    print("lidClosed=\(ClamshellWatcher.lidClosed())")
    print("sleepDisabled=\(PowerManagement.sleepDisabled())")
    print("sound=\(lidWarningURL.path) exists=\(FileManager.default.fileExists(atPath: lidWarningURL.path))")
    exit(0)
}

let watcher = ClamshellWatcher {
    // スリープ抑止していないなら普通に寝るだけなので鳴らさない。
    guard PowerManagement.sleepDisabled() else { return }
    log.notice("スリープ抑止中にフタが閉じられました")
    playLidWarning()
}
watcher.start()
log.notice("watcher 起動 sound=\(lidWarningURL.path, privacy: .public)")
RunLoop.main.run()
