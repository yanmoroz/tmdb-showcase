import Foundation

extension Optional where Wrapped == String {
    // TMDB sends "" where the field is semantically absent — tagline, homepage, release date
    var nonEmpty: String? {
        guard let self, !self.isEmpty else { return nil }
        return self
    }
}
