import Foundation

protocol TelemetryStore {
    // Write
    func logTelemetry(_ data: TelemetryData, sessionID: Int64?)

    // Sessions
    @discardableResult
    func startNewSession(name: String?, deviceID: UInt32?) -> Int64?
    func endSession(_ sessionID: Int64)

    // Reads
    func getTelemetryRecords(deviceID: UInt32?, from startDate: Date?, to endDate: Date?) -> [TelemetryRecord]
    func getTelemetryRecords(sessionID: Int64) -> [TelemetryRecord]
    func getAvailableDates(forDeviceID deviceID: UInt32?) -> [Date]
    func getAllDeviceIDs() -> [UInt32]
    func getSessions(deviceID: UInt32?) -> [Session]

    // Deletes
    func deleteRecords(olderThan date: Date)
    func deleteRecordsForDate(_ date: Date, deviceID: UInt32?)

    // Lifecycle / maintenance
    func flushChanges()
    func forceSave()
    func verifyDataStore()
}
