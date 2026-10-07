import Foundation

public enum UserRole: String, Codable, CaseIterable
{
    case motorist = "Motorist"
    case warden = "Warden"
    case admin = "Admin"

    public var title: String
    {
        switch self
        {
        case .motorist:
            return "Driver"
        case .warden:
            return "Parking Warden"
        case .admin:
            return "Admin"
        }
    }
}
