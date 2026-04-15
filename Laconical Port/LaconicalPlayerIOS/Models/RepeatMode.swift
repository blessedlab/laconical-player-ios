import Foundation

enum RepeatMode: String, CaseIterable, Codable {
    case off
    case all
    case one

    mutating func cycle() {
        switch self {
        case .off:
            self = .all
        case .all:
            self = .one
        case .one:
            self = .off
        }
    }

    var iconName: String {
        switch self {
        case .off:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }

    var isActive: Bool {
        self != .off
    }
}
