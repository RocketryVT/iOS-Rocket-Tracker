import Foundation
import GRDB
import Combine

// Conforms to TelemetryStore
class TelemetryDataManager: TelemetryStore {
    private let dbQueue: DatabaseQueue
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    private var msgNum = 0
    
    init() {
        // Get the appropriate directory for storing the database
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let databaseURL = documentsURL.appendingPathComponent("RocketTracker.sqlite")
        
        do {
            dbQueue = try DatabaseQueue(path: databaseURL.path)
            setupDatabase()
            print("Successfully created/opened database at: \(databaseURL.path)")
        } catch {
            print("Failed to create database: \(error)")
            fatalError("Could not initialize database")
        }
    }
    
    private func setupDatabase() {
        do {
            try dbQueue.write { db in
                // Create the table if it doesn't exist
                try db.create(table: "telemetryRecord", ifNotExists: true) { t in
                    t.column("sessionID", .integer).references("session", onDelete: .setNull)
                    t.autoIncrementedPrimaryKey("id")
                    t.column("deviceID", .integer).notNull()
                    t.column("msgNum", .integer).notNull()
                    t.column("timeSinceBoot", .integer).notNull()
                    t.column("timestamp", .datetime)
                    t.column("adxl_accel_x", .double).notNull()
                    t.column("adxl_accel_y", .double).notNull()
                    t.column("adxl_accel_z", .double).notNull()
                    t.column("ism_primary_accel_x", .double).notNull()
                    t.column("ism_primary_accel_y", .double).notNull()
                    t.column("ism_primary_accel_z", .double).notNull()
                    t.column("ism_primary_gyro_x", .double).notNull()
                    t.column("ism_primary_gyro_y", .double).notNull()
                    t.column("ism_primary_gyro_z", .double).notNull()
                    t.column("ism_secondary_accel_x", .double).notNull()
                    t.column("ism_secondary_accel_y", .double).notNull()
                    t.column("ism_secondary_accel_z", .double).notNull()
                    t.column("ism_secondary_gyro_x", .double).notNull()
                    t.column("ism_secondary_gyro_y", .double).notNull()
                    t.column("ism_secondary_gyro_z", .double).notNull()
                    t.column("lsm_accel_x", .double).notNull()
                    t.column("lsm_accel_y", .double).notNull()
                    t.column("lsm_accel_z", .double).notNull()
                    t.column("lsm_gyro_x", .double).notNull()
                    t.column("lsm_gyro_y", .double).notNull()
                    t.column("lsm_gyro_z", .double).notNull()
                    t.column("baro_alt", .double).notNull()
                    t.column("gps_alt", .double).notNull()
                    t.column("gps_fix", .text)
                    t.column("gps_lat", .double).notNull()
                    t.column("gps_lon", .double).notNull()
                    t.column("gps_num_sats", .integer).notNull()
                    t.column("gps_utc_day", .integer).notNull()
                    t.column("gps_utc_hour", .integer).notNull()
                    t.column("gps_utc_itow", .double).notNull()
                    t.column("gps_utc_min", .integer).notNull()
                    t.column("gps_utc_month", .integer).notNull()
                    t.column("gps_utc_nanos", .double).notNull()
                    t.column("gps_utc_sec", .integer).notNull()
                    t.column("gps_utc_time_accuracy_estimate_ns", .double).notNull()
                    t.column("gps_utc_valid", .integer).notNull()
                    t.column("gps_utc_year", .integer).notNull()
                }
                try db.create(table: "session", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("name", .text)
                    t.column("deviceID", .integer)
                    t.column("startDate", .datetime).notNull()
                    t.column("endDate", .datetime)
                }
                
                // Migration: ensure telemetryRecord has sessionID column
                do {
                    let columns = try Row.fetchAll(db, sql: "PRAGMA table_info('telemetryRecord')")
                    let hasSessionID = columns.contains { row in
                        (row["name"] as? String) == "sessionID"
                    }
                    if !hasSessionID {
                        try db.execute(sql: "ALTER TABLE telemetryRecord ADD COLUMN sessionID INTEGER")
                        print("Migrated: Added sessionID column to telemetryRecord")
                    }
                } catch {
                    print("Migration check failed: \(error)")
                }
            }
        } catch {
            print("Database setup failed: \(error)")
        }
    }
    
    // Log new telemetry data
    func logTelemetry(_ data: TelemetryData, sessionID: Int64?) {
         let record = TelemetryRecord(
             id: nil, // Let SQLite auto-increment the ID
             sessionID: sessionID,
             deviceID: Int32(data.deviceID),
             msgNum: Int32(data.msg_num),
             timeSinceBoot: Int32(data.time_since_boot),
             timestamp: Date(),
             adxl_accel_x: data.adxl.x,
             adxl_accel_y: data.adxl.y,
             adxl_accel_z: data.adxl.z,
             ism_primary_accel_x: data.ism_primary.accelerometer.x,
             ism_primary_accel_y: data.ism_primary.accelerometer.y,
             ism_primary_accel_z: data.ism_primary.accelerometer.z,
             ism_primary_gyro_x: data.ism_primary.gyroscope.x,
             ism_primary_gyro_y: data.ism_primary.gyroscope.y,
             ism_primary_gyro_z: data.ism_primary.gyroscope.z,
             ism_secondary_accel_x: data.ism_secondary.accelerometer.x,
             ism_secondary_accel_y: data.ism_secondary.accelerometer.y,
             ism_secondary_accel_z: data.ism_secondary.accelerometer.z,
             ism_secondary_gyro_x: data.ism_secondary.gyroscope.x,
             ism_secondary_gyro_y: data.ism_secondary.gyroscope.y,
             ism_secondary_gyro_z: data.ism_secondary.gyroscope.z,
             lsm_accel_x: data.lsm.accelerometer.x,
             lsm_accel_y: data.lsm.accelerometer.y,
             lsm_accel_z: data.lsm.accelerometer.z,
             lsm_gyro_x: data.lsm.gyroscope.x,
             lsm_gyro_y: data.lsm.gyroscope.y,
             lsm_gyro_z: data.lsm.gyroscope.z,
             baro_alt: data.barometer.altitude,
             gps_alt: data.gps.alt,
             gps_fix: data.gps.fix,
             gps_lat: data.gps.lat,
             gps_lon: data.gps.lon,
             gps_num_sats: Int16(data.gps.num_sats),
             gps_utc_day: Int16(data.gps.time.day),
             gps_utc_hour: Int16(data.gps.time.hour),
             gps_utc_itow: Double(data.gps.time.itow),
             gps_utc_min: Int16(data.gps.time.min),
             gps_utc_month: Int16(data.gps.time.month),
             gps_utc_nanos: Double(data.gps.time.nanos),
             gps_utc_sec: Int16(data.gps.time.sec),
             gps_utc_time_accuracy_estimate_ns: Double(data.gps.time.time_accuracy_estimate_ns),
             gps_utc_valid: Int32(data.gps.time.valid),
             gps_utc_year: Int16(data.gps.time.year)
         )
        
        
        do {
            try dbQueue.write { db in
                try record.insert(db)
            }
        } catch {
            print("Failed to save telemetry record: \(error)")
        }

        msgNum += 1
    }
    
    // Get all telemetry records for a specific device and date range
    func getTelemetryRecords(deviceID: UInt32? = nil, from startDate: Date? = nil, to endDate: Date? = nil) -> [TelemetryRecord] {
        do {
            return try dbQueue.read { db in
                var query = TelemetryRecord.all()
                
                if let deviceID = deviceID {
                    query = query.filter(TelemetryRecord.Columns.deviceID == Int32(deviceID))
                }
                
                if let startDate = startDate {
                    query = query.filter(TelemetryRecord.Columns.timestamp >= startDate)
                }
                
                if let endDate = endDate {
                    query = query.filter(TelemetryRecord.Columns.timestamp <= endDate)
                }
                
                // Sort by timestamp
                query = query.order(TelemetryRecord.Columns.timestamp.asc)
                
                return try query.fetchAll(db)
            }
        } catch {
            print("Failed to fetch telemetry records: \(error)")
            return []
        }
    }
    
    // Get telemetry records by session
    func getTelemetryRecords(sessionID: Int64) -> [TelemetryRecord] {
        do {
            return try dbQueue.read { db in
                try TelemetryRecord.filter(TelemetryRecord.Columns.sessionID == sessionID)
                    .order(TelemetryRecord.Columns.timestamp.asc)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to fetch telemetry records for session: \(error)")
            return []
        }
    }
    
    // Get all available dates that have telemetry records
    func getAvailableDates(forDeviceID deviceID: UInt32? = nil) -> [Date] {
        do {
            return try dbQueue.read { db in
                var query = """
                SELECT DISTINCT date(timestamp) as date_only FROM telemetryRecord
                """
                
                var arguments: StatementArguments = []
                
                if let deviceID = deviceID {
                    query += " WHERE deviceID = ?"
                    arguments = [Int32(deviceID)]
                }
                
                query += " ORDER BY date_only"
                
                let rows = try Row.fetchAll(db, sql: query, arguments: arguments)
                
                return rows.compactMap { row -> Date? in
                    guard let dateString = row["date_only"] as? String else { return nil }
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    return dateFormatter.date(from: dateString)
                }
            }
        } catch {
            print("Failed to fetch telemetry dates: \(error)")
            return []
        }
    }
    
    // Get all unique device IDs in the database
    func getAllDeviceIDs() -> [UInt32] {
        do {
            return try dbQueue.read { db in
                let deviceIDs = try Int32.fetchAll(db, 
                    sql: "SELECT DISTINCT deviceID FROM telemetryRecord ORDER BY deviceID")
                return deviceIDs.map { UInt32($0) }
            }
        } catch {
            print("Failed to fetch device IDs: \(error)")
            return []
        }
    }
    
    // Get sessions, optionally filtered by device
    func getSessions(deviceID: UInt32? = nil) -> [Session] {
        do {
            return try dbQueue.read { db in
                var query = Session.all()
                if let deviceID = deviceID {
                    query = query.filter(Session.Columns.deviceID == Int32(deviceID))
                }
                return try query.order(Session.Columns.startDate.desc).fetchAll(db)
            }
        } catch {
            print("Failed to fetch sessions: \(error)")
            return []
        }
    }
    
    // Delete records older than a specified date
    func deleteRecords(olderThan date: Date) {
        do {
            try dbQueue.write { db in
                let count = try TelemetryRecord.filter(TelemetryRecord.Columns.timestamp < date).deleteAll(db)
                print("Deleted \(count) old records")
            }
        } catch {
            print("Failed to delete old records: \(error)")
        }
    }
    
    // Delete records for a specific device and date
    func deleteRecordsForDate(_ date: Date, deviceID: UInt32? = nil) {
        do {
            try dbQueue.write { db in
                let calendar = Calendar.current
                
                // Get start and end of the day
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                var query = TelemetryRecord.filter(TelemetryRecord.Columns.timestamp >= startOfDay)
                    .filter(TelemetryRecord.Columns.timestamp < endOfDay)
                
                if let deviceID = deviceID {
                    query = query.filter(TelemetryRecord.Columns.deviceID == Int32(deviceID))
                }
                
                let count = try query.deleteAll(db)
                print("Found \(count) records to delete")
                print("Successfully deleted records")
            }
        } catch {
            print("Failed to delete records for date: \(error)")
        }
    }

    func flushChanges() {
        // GRDB automatically commits after each write transaction
        print("Changes saved to persistent store (automatic with GRDB)")
    }

    func forceSave() {
        // Same as above - GRDB automatically commits changes
        print("Successfully saved pending changes (automatic with GRDB)")
    }

    func verifyDataStore() {
        print("TelemetryDataManager: Verifying data store")
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let databaseURL = documentsURL.appendingPathComponent("RocketTracker.sqlite")
        
        // Check if file exists
        let fileExists = fileManager.fileExists(atPath: databaseURL.path)
        print("Store file exists: \(fileExists)")
        
        if fileExists {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: databaseURL.path)
                if let size = attributes[FileAttributeKey.size] as? NSNumber {
                    print("Store file size: \(size.intValue) bytes")
                }
                if let modDate = attributes[FileAttributeKey.modificationDate] as? Date {
                    print("Last modified: \(modDate)")
                }
            } catch {
                print("Error getting file attributes: \(error)")
            }
        }
        
        // Check the number of records
        do {
            try dbQueue.read { db in
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM telemetryRecord") ?? 0
                print("Total record count: \(count)")
            }
        } catch {
            print("Error counting records: \(error)")
        }
    }

    // Convenience for tests/demo: quickly insert synthetic telemetry data
    func insertDemoRecord(_ record: TelemetryRecord) {
        do {
            try dbQueue.write { db in
                try record.insert(db)
            }
        } catch {
            print("Failed to insert demo record: \(error)")
        }
    }

    @discardableResult
    func startNewSession(name: String?, deviceID: UInt32?) -> Int64? {
        do {
            return try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO session (name, deviceID, startDate) VALUES (?, ?, ?)", arguments: [name, deviceID != nil ? Int32(deviceID!) : nil, Date()])
                return db.lastInsertedRowID
            }
        } catch {
            print("Failed to start session: \(error)")
            return nil
        }
    }
    func endSession(_ sessionID: Int64) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "UPDATE session SET endDate = ? WHERE id = ?", arguments: [Date(), sessionID])
            }
        } catch {
            print("Failed to end session: \(error)")
        }
    }
}

