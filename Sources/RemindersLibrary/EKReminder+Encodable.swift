import EventKit

extension EKReminder: @retroactive Encodable {
    private enum EncodingKeys: String, CodingKey {
        case externalId
        case lastModified
        case creationDate
        case title
        case notes
        case url
        case location
        case locationTitle
        case completionDate
        case isCompleted
        case priority
        case startDate
        case dueDate
        case list
        case recurrence
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EncodingKeys.self)
        try container.encode(self.calendarItemExternalIdentifier, forKey: .externalId)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.isCompleted, forKey: .isCompleted)
        try container.encode(self.priority, forKey: .priority)
        try container.encode(self.calendar.title, forKey: .list)
        try container.encodeIfPresent(self.notes, forKey: .notes)
        
        // url field is nil
        // https://developer.apple.com/forums/thread/128140
        try container.encodeIfPresent(self.url, forKey: .url)
        try container.encodeIfPresent(format(self.completionDate), forKey: .completionDate)

        for alarm in self.alarms ?? [] {
            if let location = alarm.structuredLocation {
                try container.encodeIfPresent(location.title, forKey: .locationTitle)
                if let geoLocation = location.geoLocation {
                    let geo = "\(geoLocation.coordinate.latitude), \(geoLocation.coordinate.longitude)"
                    try container.encode(geo, forKey: .location)
                }
                break
            }
        }

        if let startDateComponents = self.startDateComponents {
            try container.encodeIfPresent(format(startDateComponents.date), forKey: .startDate)
        }

        if let dueDateComponents = self.dueDateComponents {
            try container.encodeIfPresent(format(dueDateComponents.date), forKey: .dueDate)
        }
        
        // e.g. [{"frequency":"weekly","interval":2}]
        if let rules = self.recurrenceRules, !rules.isEmpty {
            try container.encode(rules.map(RecurrenceRule.init), forKey: .recurrence)
        }

        if let lastModifiedDate = self.lastModifiedDate {
            try container.encode(format(lastModifiedDate), forKey: .lastModified)
        }
        
        if let creationDate = self.creationDate {
            try container.encode(format(creationDate), forKey: .creationDate)
        }
    }
    
    private func format(_ date: Date?) -> String? {
        if #available(macOS 12.0, *) {
            return date?.ISO8601Format()
        } else {
            return date?.description(with: .current)
        }
    }
}

private struct RecurrenceRule: Encodable {
    let frequency: String
    let interval: Int
    let daysOfWeek: [Int]?
    let daysOfMonth: [Int]?
    let endDate: String?
    let occurrenceCount: Int?

    init(_ rule: EKRecurrenceRule) {
        switch rule.frequency {
        case .daily: frequency = "daily"
        case .weekly: frequency = "weekly"
        case .monthly: frequency = "monthly"
        case .yearly: frequency = "yearly"
        @unknown default: frequency = "unknown"
        }
        interval = rule.interval
        daysOfWeek = rule.daysOfTheWeek?.map { $0.dayOfTheWeek.rawValue }
        daysOfMonth = rule.daysOfTheMonth?.map { $0.intValue }
        endDate = rule.recurrenceEnd?.endDate.map { ISO8601DateFormatter().string(from: $0) }
        let count = rule.recurrenceEnd?.occurrenceCount ?? 0
        occurrenceCount = count > 0 ? count : nil
    }
}
