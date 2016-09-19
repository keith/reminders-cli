extension Collection {
    func find(where predicate: (Generator.Element) throws -> Bool) rethrows -> Generator.Element? {
        return try self.index(where: predicate).flatMap { self[$0] }
    }
}

extension Collection where Index == Int, IndexDistance == Int {
    subscript(safe index: Int) -> Generator.Element? {
        return index < self.count && index >= 0 ? self[index] : nil
    }
}
