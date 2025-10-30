import Foundation

extension Array where Element: Identifiable, Element.ID: Hashable {
    /// Returns a version of the array that keeps only the last occurrence of each identifier while
    /// preserving the order of the first appearance.
    func removingDuplicateIDs() -> [Element] {
        mergingUnique(with: [])
    }

    /// Merges the array with another collection of elements, ensuring that every identifier appears
    /// at most once in the returned array. When duplicates are encountered the newest element wins
    /// but retains the position of the first occurrence, keeping the overall ordering stable.
    func mergingUnique(with newElements: [Element]) -> [Element] {
        var result: [Element] = []
        result.reserveCapacity(count + newElements.count)

        var indexByID: [Element.ID: Int] = [:]

        func appendOrReplace(_ element: Element) {
            if let existingIndex = indexByID[element.id] {
                result[existingIndex] = element
            } else {
                indexByID[element.id] = result.count
                result.append(element)
            }
        }

        for element in self {
            appendOrReplace(element)
        }

        for element in newElements {
            appendOrReplace(element)
        }

        return result
    }
}
