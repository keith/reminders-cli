import EventKit

extension EKCalendar: @retroactive Encodable {
    private enum EncodingKeys: String, CodingKey {
        case title
        case calendarIdentifier
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EncodingKeys.self)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.calendarIdentifier, forKey: .calendarIdentifier)
    }
}
