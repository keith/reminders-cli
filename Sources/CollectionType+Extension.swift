extension CollectionType {
    func find(@noescape predicate: (Generator.Element) throws -> Bool) rethrows -> Generator.Element? {
        return try self.indexOf(predicate).flatMap { self[$0] }
    }
}

extension CollectionType where Index == Int {
    subscript(safe index: Int) -> Generator.Element? {
        return index < self.count && index >= 0 ? self[index] : nil
    }
}
