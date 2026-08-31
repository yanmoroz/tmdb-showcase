import Testing
import DomainKit

@Suite("SearchText")
struct SearchTextTests {
    // The "no blank search hits the network" rule is held by the type: TMDB
    // requires `query`, and presentation does the input validation.

    @Test("Пустой ввод не даёт поискового запроса", arguments: [
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

    @Test("Пробелы по краям обрезаются")
    func trimsSurroundingWhitespace() {
        #expect(SearchText("  dune  ")?.rawValue == "dune")
        #expect(SearchText("\n dune \t")?.rawValue == "dune")
    }

    @Test("Пробелы внутри запроса сохраняются")
    func keepsInnerWhitespace() {
        #expect(SearchText("  blade runner  ")?.rawValue == "blade runner")
    }

    @Test("Запросы, отличающиеся только внешними пробелами, совпадают")
    func trimmedInputsAreEqual() {
        let lhs = SearchText("dune")
        let rhs = SearchText("  dune ")

        #expect(lhs == rhs)
        #expect(Set([lhs, rhs]).count == 1)
    }

    @Test("Регистр значим — это разные запросы")
    func caseIsSignificant() {
        #expect(SearchText("dune") != SearchText("Dune"))
    }
}
