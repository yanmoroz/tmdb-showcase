import DomainKit

extension SearchText {
    /// A guaranteed-valid search query for tests.
    public static func fixture(_ text: String = "dune") -> SearchText {
        guard let value = SearchText(text) else {
            preconditionFailure("SearchText fixture built from blank text: \(text.debugDescription)")
        }
        return value
    }
}
