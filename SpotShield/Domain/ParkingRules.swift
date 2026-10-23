import Foundation

enum ParkingRules {
    static func availableDurations(
        for zone: ParkingZone,
        at time: Date
    ) -> [Int] {
        guard zone.isPublished,
              zone.isActive,
              zone.openingHour >= 0,
              zone.openingHour <= 23,
              zone.closingHour > zone.openingHour,
              zone.closingHour <= 24,
              let closingTime = closingTime(
                on: time,
                hour: zone.closingHour,
                timeZoneId: zone.timeZoneId
              ),
              let timeZone = TimeZone(identifier: zone.timeZoneId) else {
            return []
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let currentHour = calendar.component(.hour, from: time)

        guard currentHour >= zone.openingHour,
              currentHour < zone.closingHour else {
            return []
        }

        return [30, 60, 120].filter { minutes in
            let endTime = time.addingTimeInterval(TimeInterval(minutes * 60))
            return minutes <= zone.maximumStayMinutes && endTime <= closingTime
        }
    }

    static func extensionDurations(
        for session: ParkingSession,
        at time: Date
    ) -> [Int] {
        guard session.isActive,
              session.startTime <= time,
              session.paidUntil > time,
              session.durationMinutes >= 0,
              let maximumMinutes = session.maximumStayMinutes,
              maximumMinutes >= session.durationMinutes,
              let closingHour = session.closingHour,
              let timeZoneId = session.timeZoneId,
              let closingTime = closingTime(
                on: session.startTime,
                hour: closingHour,
                timeZoneId: timeZoneId
              ) else {
            return []
        }

        let remainingMinutes = maximumMinutes - session.durationMinutes

        return [30, 60, 120].filter { minutes in
            let newEndTime = session.paidUntil.addingTimeInterval(
                TimeInterval(minutes * 60)
            )
            return minutes <= remainingMinutes && newEndTime <= closingTime
        }
    }

    static func price(
        hourlyRateLKR: Int,
        durationMinutes: Int
    ) -> Int? {
        guard hourlyRateLKR > 0,
              [30, 60, 120].contains(durationMinutes) else {
            return nil
        }

        if durationMinutes == 30 {
            return hourlyRateLKR / 2 + hourlyRateLKR % 2
        }

        let (price, overflow) = hourlyRateLKR.multipliedReportingOverflow(
            by: durationMinutes / 60
        )
        return overflow ? nil : price
    }

    private static func closingTime(
        on date: Date,
        hour: Int,
        timeZoneId: String
    ) -> Date? {
        guard (1...24).contains(hour),
              let timeZone = TimeZone(identifier: timeZoneId) else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(
            byAdding: .hour,
            value: hour,
            to: calendar.startOfDay(for: date)
        )
    }
}
