import Foundation

/// `pmset` を root として実行し、クラムシェル時のスリープ抑止を切り替える。
enum PowerManagement {
    private static let pmsetPath = "/usr/bin/pmset"

    enum Failure: Error, CustomStringConvertible {
        case launchFailed(String)
        case exitedNonZero(Int32, String)
        case notApplied(expected: Bool, actual: Bool)

        var description: String {
            switch self {
            case .launchFailed(let why):
                return "pmset を起動できませんでした: \(why)"
            case .exitedNonZero(let code, let output):
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                return "pmset が終了コード \(code) で失敗しました"
                    + (trimmed.isEmpty ? "" : ": \(trimmed)")
            case .notApplied(let expected, let actual):
                return "設定が反映されませんでした（期待 \(expected ? 1 : 0) / 実際 \(actual ? 1 : 0)）"
            }
        }
    }

    /// 現在の SleepDisabled。読み取りに root は不要。
    static func sleepDisabled() -> Bool {
        guard let output = try? capture(["-g"]) else { return false }
        for line in output.split(separator: "\n") where line.contains("SleepDisabled") {
            // ` SleepDisabled\t\t0` のようにタブ区切りで来る。
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            return fields.last == "1"
        }
        return false
    }

    /// SleepDisabled を設定し、実際に反映されたことを読み直して確認する。
    static func setSleepDisabled(_ disabled: Bool) throws {
        _ = try capture(["-a", "disablesleep", disabled ? "1" : "0"])

        // pmset は権限が足りない場合でも終了コード 0 を返すことがあるため、
        // 終了コードだけを信用せず必ず読み直して突き合わせる。
        let actual = sleepDisabled()
        guard actual == disabled else {
            throw Failure.notApplied(expected: disabled, actual: actual)
        }
    }

    @discardableResult
    private static func capture(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pmsetPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw Failure.launchFailed(error.localizedDescription)
        }

        // パイプを読み切ってから待つ。順序を逆にするとバッファが埋まった時に
        // waitUntilExit がデッドロックする。
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw Failure.exitedNonZero(process.terminationStatus, output)
        }
        return output
    }
}
