import DomainKit

extension Genre {
    public static func fixture(id: Int = 28, name: String = "Action") -> Genre {
        Genre(id: id, name: name)
    }

    public static let fixtures: [Genre] = [
        Genre(id: 28, name: "Action"),
        Genre(id: 35, name: "Comedy"),
        Genre(id: 18, name: "Drama"),
    ]
}
