import XCTest
@testable import BBB

final class EasyCycleFeedStateTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testInitialVisibleCountsForEmptyAndPartialPages() {
        let day = RecordHomeDayKey(Date(timeIntervalSince1970: 1_700_000_000), calendar: calendar)
        let state = EasyCycleFeedState()

        XCTAssertEqual(state.visibleCount(for: day, totalCount: 0), 0)
        XCTAssertEqual(state.visibleCount(for: day, totalCount: 1), 1)
        XCTAssertEqual(state.visibleCount(for: day, totalCount: 3), 3)
        XCTAssertEqual(state.visibleCount(for: day, totalCount: 4), 3)
        XCTAssertEqual(state.visibleCount(for: day, totalCount: 6), 3)
        XCTAssertEqual(state.visibleCount(for: day, totalCount: 10), 3)
    }

    func testPagesAdvanceByThreeWithoutExceedingTotal() {
        let day = RecordHomeDayKey(Date(timeIntervalSince1970: 1_700_000_000), calendar: calendar)
        var state = EasyCycleFeedState()

        XCTAssertTrue(state.loadNextPage(for: day, totalCount: 10))
        XCTAssertEqual(state.visibleCount(for: day, totalCount: 10), 6)
        XCTAssertTrue(state.loadNextPage(for: day, totalCount: 10))
        XCTAssertEqual(state.visibleCount(for: day, totalCount: 10), 9)
        XCTAssertTrue(state.loadNextPage(for: day, totalCount: 10))
        XCTAssertEqual(state.visibleCount(for: day, totalCount: 10), 10)
        XCTAssertFalse(state.loadNextPage(for: day, totalCount: 10))
        XCTAssertEqual(state.visibleCount(for: day, totalCount: 10), 10)
    }

    func testFourAndSixCycleDaysStopAtTheirExactTotals() {
        let firstDay = RecordHomeDayKey(Date(timeIntervalSince1970: 1_700_000_000), calendar: calendar)
        let secondDay = RecordHomeDayKey(Date(timeIntervalSince1970: 1_700_086_400), calendar: calendar)
        var state = EasyCycleFeedState()

        XCTAssertTrue(state.loadNextPage(for: firstDay, totalCount: 4))
        XCTAssertEqual(state.visibleCount(for: firstDay, totalCount: 4), 4)
        XCTAssertFalse(state.loadNextPage(for: firstDay, totalCount: 4))

        XCTAssertTrue(state.loadNextPage(for: secondDay, totalCount: 6))
        XCTAssertEqual(state.visibleCount(for: secondDay, totalCount: 6), 6)
        XCTAssertFalse(state.loadNextPage(for: secondDay, totalCount: 6))
    }

    func testDateStatesAndAnchorsRemainIndependent() {
        let firstDay = RecordHomeDayKey(Date(timeIntervalSince1970: 1_700_000_000), calendar: calendar)
        let secondDay = RecordHomeDayKey(Date(timeIntervalSince1970: 1_700_086_400), calendar: calendar)
        let firstAnchor = UUID()
        let secondAnchor = UUID()
        var state = EasyCycleFeedState()

        state.loadNextPage(for: firstDay, totalCount: 10)
        state.rememberTopVisibleCycle(firstAnchor, for: firstDay)
        state.rememberTopVisibleCycle(secondAnchor, for: secondDay)

        XCTAssertEqual(state.visibleCount(for: firstDay, totalCount: 10), 6)
        XCTAssertEqual(state.visibleCount(for: secondDay, totalCount: 10), 3)
        XCTAssertEqual(state.anchor(for: firstDay), firstAnchor)
        XCTAssertEqual(state.anchor(for: secondDay), secondAnchor)
    }

    func testVisiblePrefixKeepsStableOrderAndHasNoDuplicates() {
        let day = RecordHomeDayKey(Date(timeIntervalSince1970: 1_700_000_000), calendar: calendar)
        let identifiers = (0..<10).map { _ in UUID() }
        var state = EasyCycleFeedState()

        let initial = Array(identifiers.prefix(state.visibleCount(for: day, totalCount: identifiers.count)))
        state.loadNextPage(for: day, totalCount: identifiers.count)
        let secondPage = Array(identifiers.prefix(state.visibleCount(for: day, totalCount: identifiers.count)))

        XCTAssertEqual(initial, Array(identifiers.prefix(3)))
        XCTAssertEqual(secondPage, Array(identifiers.prefix(6)))
        XCTAssertEqual(Set(secondPage).count, secondPage.count)
    }
}
