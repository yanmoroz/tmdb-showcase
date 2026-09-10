import PresentationKit

/// What the presenter may ask of the details screen.
///
/// The status is additive rather than an overlay: the screen is seeded with the
/// `Movie` the list already holds, so there is always something on it and a
/// failure must not replace it.
@MainActor
protocol MovieDetailsView: AnyObject {
    func show(_ model: MovieDetailsModel)
    func setSaved(_ isSaved: Bool)

    func showLoading()
    func showFailure(_ message: String, retry: Bool)
    func hideStatus()

    func showToast(_ message: String)
}
