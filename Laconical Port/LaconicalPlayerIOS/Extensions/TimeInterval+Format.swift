import Foundation

extension TimeInterval {
    var mmss: String {
        guard isFinite, self > 0 else { return "0:00" }
        let total = Int(self.rounded(.down))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
