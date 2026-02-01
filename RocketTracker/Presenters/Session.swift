import Foundation
import GRDB

struct Session: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var name: String?
    var deviceID: Int32?
    var startDate: Date
    var endDate: Date?
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let deviceID = Column(CodingKeys.deviceID)
        static let startDate = Column(CodingKeys.startDate)
        static let endDate = Column(CodingKeys.endDate)
    }
}
