import Foundation
import Testing
@testable import SpotShield

@Suite("Parking rules")
struct ParkingRulesTests {
    @Test("An open zone offers durations within its stay limit")
    func availableDurationsRespectMaximumStay() {
        let zone = makeZone(maximumStayMinutes: 60)

        #expect(ParkingRules.availableDurations(for: zone, at: colomboTime(9)) == [30, 60])
    }

    @Test("A zone must be published and active")
    func unavailableZoneOffersNoDurations() {
        var zone = makeZone(isPublished: false)
        #expect(ParkingRules.availableDurations(for: zone, at: colomboTime(9)).isEmpty)

        zone.isPublished = true
        zone.isActive = false
        #expect(ParkingRules.availableDurations(for: zone, at: colomboTime(9)).isEmpty)
    }

    @Test("Parking is unavailable before opening and at closing")
    func zoneHoursAreEnforced() {
        let zone = makeZone()

        #expect(ParkingRules.availableDurations(for: zone, at: colomboTime(7, 59)).isEmpty)
        #expect(ParkingRules.availableDurations(for: zone, at: colomboTime(18)).isEmpty)
    }

    @Test("A duration cannot end after the zone closes")
    func durationsRespectClosingTime() {
        let zone = makeZone()

        #expect(ParkingRules.availableDurations(for: zone, at: colomboTime(17, 30)) == [30])
        #expect(ParkingRules.availableDurations(for: zone, at: colomboTime(17, 31)).isEmpty)
    }

    @Test("Invalid zone hours or time zone make parking unavailable")
    func invalidZoneConfigurationOffersNoDurations() {
        var zone = makeZone(openingHour: 24)
        #expect(ParkingRules.availableDurations(for: zone, at: colomboTime(9)).isEmpty)

        zone = makeZone(closingHour: 8)
        #expect(ParkingRules.availableDurations(for: zone, at: colomboTime(9)).isEmpty)

        zone = makeZone(timeZoneId: "Unknown/Zone")
        #expect(ParkingRules.availableDurations(for: zone, at: colomboTime(9)).isEmpty)
    }

    @Test("Half-hour prices round upward and full-hour prices multiply")
    func pricesUseExpectedRounding() {
        #expect(ParkingRules.price(hourlyRateLKR: 200, durationMinutes: 30) == 100)
        #expect(ParkingRules.price(hourlyRateLKR: 201, durationMinutes: 30) == 101)
        #expect(ParkingRules.price(hourlyRateLKR: 200, durationMinutes: 60) == 200)
        #expect(ParkingRules.price(hourlyRateLKR: 200, durationMinutes: 120) == 400)
    }

    @Test("Invalid rates and durations have no price")
    func invalidPriceInputsAreRejected() {
        #expect(ParkingRules.price(hourlyRateLKR: 0, durationMinutes: 30) == nil)
        #expect(ParkingRules.price(hourlyRateLKR: -1, durationMinutes: 60) == nil)
        #expect(ParkingRules.price(hourlyRateLKR: 200, durationMinutes: 45) == nil)
    }

    @Test("Price calculation rejects integer overflow")
    func priceOverflowIsRejected() {
        #expect(ParkingRules.price(hourlyRateLKR: Int.max, durationMinutes: 120) == nil)
    }

    @Test("An extension respects remaining stay and zone closing time")
    func extensionDurationsRespectLimits() {
        var session = makeSession(
            startHour: 9,
            paidUntilHour: 9,
            paidUntilMinute: 30,
            durationMinutes: 30,
            maximumStayMinutes: 120
        )

        #expect(ParkingRules.extensionDurations(for: session, at: colomboTime(9, 10)) == [30, 60])

        session = makeSession(
            startHour: 16,
            paidUntilHour: 17,
            paidUntilMinute: 30,
            durationMinutes: 60,
            maximumStayMinutes: 120
        )
        #expect(ParkingRules.extensionDurations(for: session, at: colomboTime(17, 10)) == [30])
    }

    @Test("An inactive, expired or future session cannot be extended")
    func invalidExtensionSessionIsRejected() {
        var session = makeSession(startHour: 9, paidUntilHour: 10)
        session.isActive = false
        #expect(ParkingRules.extensionDurations(for: session, at: colomboTime(9, 30)).isEmpty)

        session = makeSession(startHour: 9, paidUntilHour: 9, paidUntilMinute: 30)
        #expect(ParkingRules.extensionDurations(for: session, at: colomboTime(9, 30)).isEmpty)

        session = makeSession(startHour: 10, paidUntilHour: 11)
        #expect(ParkingRules.extensionDurations(for: session, at: colomboTime(9, 30)).isEmpty)
    }

    @Test("A session at its maximum stay has no extension durations")
    func maximumStayHasNoExtensions() {
        let session = makeSession(
            startHour: 9,
            paidUntilHour: 10,
            durationMinutes: 120,
            maximumStayMinutes: 120
        )

        #expect(ParkingRules.extensionDurations(for: session, at: colomboTime(9, 30)).isEmpty)
    }

    @Test("Only valid and expiring parking counts as valid")
    func validParkingStatusesAreRecognized() {
        #expect(PlateCheckResult(status: .valid, parkingStatus: "", checkedAt: colomboTime(9)).hasValidParking)
        #expect(PlateCheckResult(status: .expiring, parkingStatus: "", checkedAt: colomboTime(9)).hasValidParking)
        #expect(!PlateCheckResult(status: .overstay, parkingStatus: "", checkedAt: colomboTime(9)).hasValidParking)
        #expect(!PlateCheckResult(status: .noCheckIn, parkingStatus: "", checkedAt: colomboTime(9)).hasValidParking)
    }

    @Test("Only overstay and no check-in can be reported")
    func reportableParkingStatusesAreRestricted() {
        #expect(ParkingStatus.overstay.canReport)
        #expect(ParkingStatus.noCheckIn.canReport)
        #expect(!ParkingStatus.valid.canReport)
        #expect(!ParkingStatus.expiring.canReport)
        #expect(!ParkingStatus.cannotCheck.canReport)
        #expect(!ParkingStatus.outsideHours.canReport)
        #expect(!ParkingStatus.inactiveZone.canReport)
    }

    private func makeZone(
        isPublished: Bool = true,
        isActive: Bool = true,
        openingHour: Int = 8,
        closingHour: Int = 18,
        maximumStayMinutes: Int = 120,
        timeZoneId: String = "Asia/Colombo"
    ) -> ParkingZone {
        ParkingZone(
            id: "zone-1",
            name: "Test Zone",
            hourlyRateLKR: 200,
            latitude: 6.9,
            longitude: 79.8,
            radiusMeters: 100,
            openingHour: openingHour,
            closingHour: closingHour,
            maximumStayMinutes: maximumStayMinutes,
            timeZoneId: timeZoneId,
            isPublished: isPublished,
            isActive: isActive
        )
    }

    private func makeSession(
        startHour: Int,
        paidUntilHour: Int,
        paidUntilMinute: Int = 0,
        durationMinutes: Int = 60,
        maximumStayMinutes: Int? = 120
    ) -> ParkingSession {
        ParkingSession(
            id: "session-1",
            userId: "user-1",
            vehicleId: "vehicle-1",
            parkingZoneId: "zone-1",
            zoneName: "Test Zone",
            licensePlate: "CBB-1234",
            startTime: colomboTime(startHour),
            paidUntil: colomboTime(paidUntilHour, paidUntilMinute),
            endTime: nil,
            durationMinutes: durationMinutes,
            hourlyRateLKR: 200,
            totalPaidLKR: 200,
            policyVersion: 1,
            isActive: true,
            operationId: "operation-1",
            maximumStayMinutes: maximumStayMinutes,
            openingHour: 8,
            closingHour: 18,
            timeZoneId: "Asia/Colombo"
        )
    }

    private func colomboTime(_ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Colombo")!
        return calendar.date(
            from: DateComponents(
                year: 2026,
                month: 10,
                day: 23,
                hour: hour,
                minute: minute
            )
        )!
    }
}
