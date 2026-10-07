import Foundation

public enum ParkingStatus: String, Codable, CaseIterable
{
    case valid = "Valid"
    case expiring = "Expiring Soon"
    case overstay = "Overstay"
    case noCheckIn = "No Check-in"
    case cannotCheck = "Cannot Check"
    case outsideHours = "Outside Hours"
    case inactiveZone = "Inactive Zone"
    
    public var message: String
    {
        switch self
        {
        case .valid:
            return "A current parking session was found in this zone."
        case .expiring:
            return "The paid parking time is nearly over."
        case .overstay:
            return "The paid parking time has ended."
        case .noCheckIn:
            return "No active parking session was found in this zone."
        case .cannotCheck:
            return "We can't check right now. Please try again."
        case .outsideHours:
            return "Wardens aren't checking this zone right now."
        case .inactiveZone:
            return "This parking zone is not active."
        }
    }
    
    
    public var canReport: Bool
    {
        switch self
        {
        case .overstay, .noCheckIn:
            return true
        case .valid, .expiring, .cannotCheck, .outsideHours, .inactiveZone:
            return false
        }
    }
}
