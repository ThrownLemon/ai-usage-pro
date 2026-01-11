import XCTest
@testable import ClaudeUsagePro

final class DateFormattingHelperTests: XCTestCase {

    // MARK: - ISO8601 Parsing Tests

    func testParseISO8601WithFractionalSeconds() {
        // Given
        let isoDate = "2025-01-15T14:30:00.123Z"

        // When
        let result = DateFormattingHelper.parseISO8601(isoDate)

        // Then
        XCTAssertNotNil(result)
    }

    func testParseISO8601WithoutFractionalSeconds() {
        // Given
        let isoDate = "2025-01-15T14:30:00Z"

        // When
        let result = DateFormattingHelper.parseISO8601(isoDate)

        // Then
        XCTAssertNotNil(result)
    }

    func testParseISO8601InvalidDate() {
        // Given
        let isoDate = "not-a-date"

        // When
        let result = DateFormattingHelper.parseISO8601(isoDate)

        // Then
        XCTAssertNil(result)
    }

    // MARK: - Time Remaining Tests

    func testFormatTimeRemainingFuture() {
        // Given - a date 3 hours and 21 minutes in the future from NOW
        let futureDate = Date().addingTimeInterval(3 * 3600 + 21 * 60)

        // When
        let result = DateFormattingHelper.formatTimeRemaining(futureDate)

        // Then - the result should be a time format like "3h 21m"
        XCTAssertTrue(result.contains("h") && result.contains("m"),
                      "Expected time format like 'Xh Ym', got: \(result)")
        XCTAssertTrue(result.hasPrefix("3h"), "Expected to start with '3h', got: \(result)")
    }

    func testFormatTimeRemainingPast() {
        // Given - a date in the past
        let pastDate = Date().addingTimeInterval(-3600)

        // When
        let result = DateFormattingHelper.formatTimeRemaining(pastDate)

        // Then
        XCTAssertEqual(result, Constants.Status.ready)
    }

    func testFormatTimeRemainingNow() {
        // Given - current time
        let now = Date()

        // When
        let result = DateFormattingHelper.formatTimeRemaining(now)

        // Then
        XCTAssertEqual(result, Constants.Status.ready)
    }

    // MARK: - Reset Time Formatting Tests

    func testFormatResetTimeValidDate() {
        // Given - a future date in ISO format
        let calendar = Calendar.current
        let futureDate = calendar.date(byAdding: .hour, value: 2, to: Date())!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoDate = formatter.string(from: futureDate)

        // When
        let result = DateFormattingHelper.formatResetTime(isoDate: isoDate)

        // Then
        XCTAssertTrue(result.contains("h"))
        XCTAssertTrue(result.contains("m"))
        XCTAssertFalse(result.contains("T")) // Should not contain ISO format
    }

    func testFormatResetTimeInvalidDate() {
        // Given - an invalid date string
        let invalidDate = "invalid-date"

        // When
        let result = DateFormattingHelper.formatResetTime(isoDate: invalidDate)

        // Then
        XCTAssertEqual(result, invalidDate) // Returns original string on failure
    }

    // MARK: - Date Display Formatting Tests

    func testFormatDateDisplay() {
        // Given - a specific known date (Jan 15, 2025 at 2:30 PM UTC)
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 14
        components.minute = 30
        components.timeZone = TimeZone(identifier: "UTC")
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        // When
        let result = DateFormattingHelper.formatDateDisplay(date)

        // Then - Result should contain day abbreviation and AM/PM time
        XCTAssertFalse(result.isEmpty)
        // Should match format "E h:mm a" (e.g., "Wed 2:30 PM" or localized equivalent)
        XCTAssertTrue(result.count >= 8, "Expected at least 8 chars for 'E h:mm a' format, got: \(result)")
        // Should contain a colon for time
        XCTAssertTrue(result.contains(":"), "Expected time with colon, got: \(result)")
    }

    func testFormatResetDateValidDate() {
        // Given - a future date in ISO format
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let isoDate = formatter.string(from: Date())

        // When
        let result = DateFormattingHelper.formatResetDate(isoDate: isoDate)

        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertFalse(result.contains("T")) // Should be formatted, not ISO
    }
}
