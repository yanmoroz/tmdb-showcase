/// One row of either filter section, already decided: the view draws a title and
/// a tick and knows nothing about `Genre` or `MovieSortOption`.
public struct FilterRow: Equatable {
    public let title: String
    public let isChecked: Bool

    public init(title: String, isChecked: Bool) {
        self.title = title
        self.isChecked = isChecked
    }
}
