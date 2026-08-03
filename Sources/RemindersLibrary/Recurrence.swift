import ArgumentParser
import EventKit
import Foundation

/// A simple recurrence specification parsed from a `--repeat` CLI option, e.g.
/// `daily`, `weekly`, `monthly`, `yearly`, or with an interval like `2-weeks`.
///
/// This intentionally covers the common cases (frequency + interval) rather
/// than the full expressiveness of `EKRecurrenceRule` (day-of-week sets,
/// end conditions, etc). Those can be layered on later if needed.
public struct Recurrence: ExpressibleByArgument {
    public let frequency: EKRecurrenceFrequency
    public let interval: Int

    public init?(argument: String) {
        let lowered = argument.lowercased()
        // Reject a leading '-' up front: `split(separator:)` omits empty
        // subsequences by default, so "-1-weeks" would otherwise silently
        // lose its sign and parse as the (wrong) positive interval 1.
        guard !lowered.hasPrefix("-") else { return nil }

        let parts = lowered.split(separator: "-", maxSplits: 1)

        let intervalPart: Int
        let frequencyPart: Substring

        if parts.count == 2, let parsedInterval = Int(parts[0]) {
            intervalPart = parsedInterval
            frequencyPart = parts[1]
        } else {
            intervalPart = 1
            frequencyPart = lowered[...]
        }

        guard intervalPart > 0 else { return nil }

        switch frequencyPart {
        case "day", "days", "daily":
            self.frequency = .daily
        case "week", "weeks", "weekly":
            self.frequency = .weekly
        case "month", "months", "monthly":
            self.frequency = .monthly
        case "year", "years", "yearly", "annually":
            self.frequency = .yearly
        default:
            return nil
        }

        self.interval = intervalPart
    }

    var recurrenceRule: EKRecurrenceRule {
        EKRecurrenceRule(
            recurrenceWith: self.frequency,
            interval: self.interval,
            end: nil)
    }

    static var helpText: String {
        "Make the reminder recurring, one of: daily, weekly, monthly, yearly, " +
        "or with an interval like '2-weeks' or '3-months'"
    }
}

extension EKRecurrenceRule {
    /// A short, stable string representation used for JSON/plain output,
    /// e.g. "weekly", "2-weeks".
    var shortDescription: String {
        let unit: String
        switch self.frequency {
        case .daily: unit = "days"
        case .weekly: unit = "weeks"
        case .monthly: unit = "months"
        case .yearly: unit = "years"
        @unknown default: unit = "occurrences"
        }

        if self.interval == 1 {
            switch self.frequency {
            case .daily: return "daily"
            case .weekly: return "weekly"
            case .monthly: return "monthly"
            case .yearly: return "yearly"
            @unknown default: return "1-\(unit)"
            }
        }

        return "\(self.interval)-\(unit)"
    }
}
