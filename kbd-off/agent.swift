import Foundation
import IOKit.hid

// 入力監視の許可を要求(初回だけダイアログ/一覧に登録される)
_ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)

// 実行ファイルと同じディレクトリの check.sh を呼ぶ
let script = Bundle.main.executableURL!
    .resolvingSymlinksInPath()
    .deletingLastPathComponent()
    .appendingPathComponent("check.sh").path
while true {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = [script]
    try? p.run()
    p.waitUntilExit()
    Thread.sleep(forTimeInterval: 5)
}
