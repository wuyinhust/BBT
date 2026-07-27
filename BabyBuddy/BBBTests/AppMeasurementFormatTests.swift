import XCTest

final class AppMeasurementFormatTests: XCTestCase {
    private var originalPreference: String?

    override func setUp() {
        super.setUp()
        originalPreference = MeasurementSystemPreference.defaults.string(
            forKey: MeasurementSystemPreference.storageKey
        )
    }

    override func tearDown() {
        if let originalPreference {
            MeasurementSystemPreference.defaults.set(
                originalPreference,
                forKey: MeasurementSystemPreference.storageKey
            )
        } else {
            MeasurementSystemPreference.defaults.removeObject(
                forKey: MeasurementSystemPreference.storageKey
            )
        }
        super.tearDown()
    }

    func testExplicitPreferencesResolveDeterministically() {
        XCTAssertEqual(AppMeasurementFormat.resolvedSystem(preference: .metric), .metric)
        XCTAssertEqual(AppMeasurementFormat.resolvedSystem(preference: .imperial), .imperial)
    }

    func testFollowRegionUsesLocaleMeasurementSystem() {
        XCTAssertEqual(
            AppMeasurementFormat.resolvedSystem(
                preference: .followRegion,
                locale: Locale(identifier: "fr_FR")
            ),
            .metric
        )
        XCTAssertEqual(
            AppMeasurementFormat.resolvedSystem(
                preference: .followRegion,
                locale: Locale(identifier: "en_US")
            ),
            .imperial
        )
    }

    func testPoundsAndOuncesRoundTrip() {
        let originalKilograms = 3.5
        let imperial = AppMeasurementFormat.poundsAndOunces(fromKilograms: originalKilograms)
        let roundTrip = AppMeasurementFormat.kilograms(
            pounds: Double(imperial.pounds),
            ounces: imperial.ounces
        )

        XCTAssertEqual(imperial.pounds, 7)
        XCTAssertEqual(imperial.ounces, 11.5, accuracy: 0.1)
        XCTAssertEqual(roundTrip, originalKilograms, accuracy: 0.005)
    }

    func testSixteenOuncesCarriesToOnePound() {
        let value = AppMeasurementFormat.poundsAndOunces(fromKilograms: 0.453_592_37)
        XCTAssertEqual(value.pounds, 1)
        XCTAssertEqual(value.ounces, 0, accuracy: 0.1)
    }

    func testVolumeRoundTripUsesUSFluidOunces() {
        setPreference(.imperial)
        let milliliters = AppMeasurementFormat.milliliters(fromVolumeValue: 1)
        XCTAssertEqual(milliliters, 29.5735, accuracy: 0.0001)
        XCTAssertEqual(
            AppMeasurementFormat.volumeValue(fromMilliliters: milliliters),
            1,
            accuracy: 0.0001
        )
    }

    func testHeightAndSolidMassRoundTrip() {
        setPreference(.imperial)
        let inches = AppMeasurementFormat.heightValue(fromCentimeters: 68)
        XCTAssertEqual(
            AppMeasurementFormat.centimeters(fromHeightValue: inches),
            68,
            accuracy: 0.0001
        )

        let ounces = AppMeasurementFormat.massValue(fromGrams: 30)
        XCTAssertEqual(
            AppMeasurementFormat.grams(fromMassValue: ounces),
            30,
            accuracy: 0.0001
        )
    }

    func testChangingPreferenceDoesNotChangeCanonicalValue() {
        let canonicalMilliliters = 120.0
        setPreference(.metric)
        let metricValue = AppMeasurementFormat.volumeValue(fromMilliliters: canonicalMilliliters)
        setPreference(.imperial)
        let imperialValue = AppMeasurementFormat.volumeValue(fromMilliliters: canonicalMilliliters)

        XCTAssertEqual(metricValue, canonicalMilliliters)
        XCTAssertNotEqual(imperialValue, canonicalMilliliters)
        XCTAssertEqual(
            AppMeasurementFormat.milliliters(fromVolumeValue: imperialValue),
            canonicalMilliliters,
            accuracy: 0.0001
        )
    }

    func testZeroAndNegativeInputsAreSafe() {
        XCTAssertEqual(AppMeasurementFormat.kilograms(pounds: -1, ounces: -2), 0)
        let zero = AppMeasurementFormat.poundsAndOunces(fromKilograms: 0)
        XCTAssertEqual(zero.pounds, 0)
        XCTAssertEqual(zero.ounces, 0)
    }

    private func setPreference(_ preference: MeasurementSystemPreference) {
        MeasurementSystemPreference.defaults.set(
            preference.rawValue,
            forKey: MeasurementSystemPreference.storageKey
        )
    }
}
