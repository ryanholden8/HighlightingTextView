import XCTest
@testable import HighlightingTextView

final class HighlightingTextViewTests: XCTestCase {
    func testExample() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        
        await MainActor.run {
            let view = HighlightTextView(frame: .zero, textContainer: nil)
            
            view.text = "Hello, World!"
            
            XCTAssertEqual(view.text, "Hello, World!")
        }
        
    }
}
