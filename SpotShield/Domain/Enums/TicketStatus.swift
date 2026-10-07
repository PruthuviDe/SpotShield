import Foundation

public enum TicketStatus: String, Codable, CaseIterable
{
    case paid = "Paid"
    case due = "Due"
    case pending = "Checking"

    public var message: String
    {
        switch self
        {
        case .paid:
            return "Fine was paid from wallet."
        case .due:
            return "Fine is unpaid."
        case .pending:
            return "Payment is being processed."
        }
    }
}
