import EventKit

extension EKReminder: Encodable {
    private enum EncodingKeys: String, CodingKey {
        case externalId
        case title
        case notes
        case url
        case location
        case completionDate
        case isCompleted
        case priority
        case startDate
        case dueDate
        case list
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EncodingKeys.self)
        try container.encode(self.calendarItemExternalIdentifier, forKey: .externalId)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.isCompleted, forKey: .isCompleted)
        try container.encode(self.priority, forKey: .priority)
        try container.encode(self.calendar.title, forKey: .list)
        try container.encodeIfPresent(self.notes, forKey: .notes)
        try container.encodeIfPresent(self.url, forKey: .url)
        try container.encodeIfPresent(self.location, forKey: .location)
        try container.encodeIfPresent(self.completionDate, forKey: .completionDate)

        if let startDateComponents = self.startDateComponents {
            if #available(macOS 12.0, *) {
                try container.encode(startDateComponents.date?.ISO8601Format(), forKey: .startDate)
            } else {
                try container.encode(startDateComponents.date?.description(with: .current), forKey: .startDate)
            }
        }

        if let dueDateComponents = self.dueDateComponents {
            if #available(macOS 12.0, *) {
                try container.encode(dueDateComponents.date?.ISO8601Format(), forKey: .dueDate)
            } else {
                try container.encode(dueDateComponents.date?.description(with: .current), forKey: .dueDate)
            }
        }
    }
}
