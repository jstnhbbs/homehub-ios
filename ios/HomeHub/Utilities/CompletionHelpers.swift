import Foundation

enum CompletionHelpers {
    /// "Alex · 3:42 PM" for something done today, "Alex · Tue 3:42 PM" for an earlier day,
    /// or just the name or time when only one is known. Nil when neither is.
    static func caption(name: String?, completedAt: Date?, timezone: TimeZone, now: Date = .now) -> String? {
        let person = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = (person?.isEmpty == false) ? person : nil

        var when: String?
        if let completedAt {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timezone
            let formatter = DateFormatter()
            formatter.timeZone = timezone
            if calendar.isDate(completedAt, inSameDayAs: now) {
                formatter.timeStyle = .short
                formatter.dateStyle = .none
            } else {
                formatter.setLocalizedDateFormatFromTemplate("EEEjm")
            }
            when = formatter.string(from: completedAt)
        }

        switch (who, when) {
        case let (who?, when?): return "\(who) · \(when)"
        case let (who?, nil): return who
        case let (nil, when?): return when
        case (nil, nil): return nil
        }
    }
}
