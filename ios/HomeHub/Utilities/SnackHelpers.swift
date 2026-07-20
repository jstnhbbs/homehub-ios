import Foundation

enum SnackHelpers {
    static func parseSnackOptions(_ value: String?) -> [String] {
        guard let value, !value.isEmpty else { return [] }
        return value
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func serializeSnackOptions(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }
}
