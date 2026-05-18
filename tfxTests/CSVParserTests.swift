#if os(macOS)
import Testing
@testable import tfx

@Suite("CSVParser")
struct CSVParserTests {
    @Test
    func emptyInput() {
        let rows = CSVParser.parse("", delimiter: ",")
        #expect(rows.isEmpty)
    }

    @Test
    func singleRow() {
        let rows = CSVParser.parse("a,b,c", delimiter: ",")
        #expect(rows == [["a", "b", "c"]])
    }

    @Test
    func multipleRowsLF() {
        let rows = CSVParser.parse("a,b\nc,d", delimiter: ",")
        #expect(rows == [["a", "b"], ["c", "d"]])
    }

    @Test
    func multipleRowsCRLF() {
        let rows = CSVParser.parse("a,b\r\nc,d", delimiter: ",")
        #expect(rows == [["a", "b"], ["c", "d"]])
    }

    @Test
    func trailingNewlineDoesNotProduceEmptyRow() {
        let rows = CSVParser.parse("a,b\n", delimiter: ",")
        #expect(rows == [["a", "b"]])
    }

    @Test
    func emptyFieldsPreserved() {
        let rows = CSVParser.parse("a,,c", delimiter: ",")
        #expect(rows == [["a", "", "c"]])
    }

    @Test
    func quotedFieldContainingDelimiter() {
        let rows = CSVParser.parse("\"a,b\",c", delimiter: ",")
        #expect(rows == [["a,b", "c"]])
    }

    @Test
    func quotedFieldContainingEscapedQuote() {
        let rows = CSVParser.parse("\"a\"\"b\",c", delimiter: ",")
        #expect(rows == [["a\"b", "c"]])
    }

    @Test
    func quotedFieldContainingNewline() {
        let rows = CSVParser.parse("\"a\nb\",c", delimiter: ",")
        #expect(rows == [["a\nb", "c"]])
    }

    @Test
    func tabDelimiter() {
        let rows = CSVParser.parse("a\tb\tc", delimiter: "\t")
        #expect(rows == [["a", "b", "c"]])
    }

    @Test
    func mixedQuotedAndUnquotedFields() {
        let rows = CSVParser.parse("a,\"b, c\",d\ne,f,\"g\"", delimiter: ",")
        #expect(rows == [["a", "b, c", "d"], ["e", "f", "g"]])
    }
}
#endif
