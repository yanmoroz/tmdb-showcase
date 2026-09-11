import DomainKit
import PresentationKit

enum MoviesModels {
    enum Request {
        struct Start {}
        struct Reload {}
        struct ReloadSavedIDs {}

        struct ChangeSearchText {
            let text: String
        }

        struct ChangeSource {
            let source: MoviesFilter.Source
        }

        struct ApplyFilter {
            let filter: MoviesFilter
        }

        struct WillDisplayItem {
            let index: Int
        }

        struct ToggleWatchlist {
            let index: Int
        }

        struct SelectMovie {
            let index: Int
        }
    }

    enum Response {
        struct Feed {
            let movies: [Movie]
            let savedIDs: Set<Movie.ID>
        }

        struct Item: Equatable {
            let index: Int
            let movie: Movie
            let isSaved: Bool
        }

        struct Overlay: Equatable {
            enum Activity: Equatable {
                case idle
                case loading
                case failed(AppError)
            }

            let activity: Activity
            let isEmpty: Bool
            let isSearching: Bool
        }

        struct Failure {
            let error: AppError
        }

        struct InputAvailability: Equatable {
            let hasSearchText: Bool
            let allowsRefinement: Bool
        }

        struct RefreshEnded {}
        struct ScrollToTop {}
        struct MovieSelection {}
    }

    enum ViewModel {
        struct Feed {
            let items: [MovieCell.Model]
        }

        struct Item {
            let index: Int
            let item: MovieCell.Model
        }

        enum Overlay: Equatable {
            case loading
            case empty(isSearch: Bool)
            case failure(message: String, retry: Bool)
            case hidden
        }

        struct Toast {
            let message: String
        }

        struct InputAvailability: Equatable {
            let sourceEnabled: Bool
            let filterEnabled: Bool
        }

        struct RefreshEnded {}
        struct ScrollToTop {}
        struct MovieSelection {}
    }
}
