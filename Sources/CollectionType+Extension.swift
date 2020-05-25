extension Collection {
    func find(where predicate: (Iterator.Element) throws -> Bool) rethrows -> Iterator.Element? {
        return try self.firstIndex(where: predicate).flatMap { self[$0] }
    }
}

extension Collection where Index == Int {
    subscript(safe index: Int) -> Iterator.Element? {
        return index < self.count && index >= 0 ? self[index] : nil
    }
}
