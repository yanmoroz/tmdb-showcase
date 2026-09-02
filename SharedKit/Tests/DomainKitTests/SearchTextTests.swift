import Testing
import DomainKit

@Suite("SearchText")
struct SearchTextTests {
    // The "no blank search hits the network" rule is held by the type: TMDB
    // requires `query`, and presentation does the input validation.

    @Test("Blank input yields no search query", arguments: [
        "",
        " ",
        "   ",
        "\n",
        "\t",
        " \n\t ",
    ])
    func rejectsBlankInput(input: String) {
        #expect(SearchText(input) == nil)
    }

    @Test("Surrounding whitespace is trimmed")
    func trimsSurroundingWhitespace() {
        #expect(SearchText("  dune  ")?.rawValue == "dune")
        #expect(SearchText("\n dune \t")?.rawValue == "dune")
    }

    @Test("Whitespace inside the query is preserved")
    func keepsInnerWhitespace() {
        #expect(SearchText("  blade runner  ")?.rawValue == "blade runner")
    }

    @Test("Queries differing only in outer whitespace are equal")
    func trimmedInputsAreEqual() {
        let lhs = SearchText("dune")
        let rhs = SearchText("  dune ")

        #expect(lhs == rhs)
        #expect(Set([lhs, rhs]).count == 1)
    }

    @Test("Case is significant — these are different queries")
    func caseIsSignificant() {
        #expect(SearchText("dune") != SearchText("Dune"))
    }
}
