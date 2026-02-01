import Foundation

struct CSVExporter {
    static func export(records: [TelemetryRecord], fileNamePrefix: String = "RocketTelemetry") throws -> URL {
        var csvString = "Device ID,Message #,Time Since Boot,Timestamp," +
            "ADXL Accel X,ADXL Accel Y,ADXL Accel Z," +
            "ISM Primary Accel X,ISM Primary Accel Y,ISM Primary Accel Z," +
            "ISM Primary Gyro X,ISM Primary Gyro Y,ISM Primary Gyro Z," +
            "ISM Secondary Accel X,ISM Secondary Accel Y,ISM Secondary Accel Z," +
            "ISM Secondary Gyro X,ISM Secondary Gyro Y,ISM Secondary Gyro Z," +
            "LSM Accel X,LSM Accel Y,LSM Accel Z," +
            "LSM Gyro X,LSM Gyro Y,LSM Gyro Z," +
            "Barometer Alt,GPS Alt,GPS Fix,GPS Lat,GPS Lon,GPS Satellites," +
            "GPS UTC Day,GPS UTC Hour,GPS UTC ITOW,GPS UTC Min,GPS UTC Month," +
            "GPS UTC Nanos,GPS UTC Sec,GPS UTC Time Accuracy,GPS UTC Valid,GPS UTC Year\n"

        let isoFormatter = ISO8601DateFormatter()

        for record in records {
            let timestamp = record.timestamp ?? Date()
            let formattedDate = isoFormatter.string(from: timestamp)
            let gpsFix = record.gps_fix ?? "Unknown"

            let line = """
            \(record.deviceID),\
            \(record.msgNum),\
            \(record.timeSinceBoot),\
            \(formattedDate),\
            \(record.adxl_accel_x),\
            \(record.adxl_accel_y),\
            \(record.adxl_accel_z),\
            \(record.ism_primary_accel_x),\
            \(record.ism_primary_accel_y),\
            \(record.ism_primary_accel_z),\
            \(record.ism_primary_gyro_x),\
            \(record.ism_primary_gyro_y),\
            \(record.ism_primary_gyro_z),\
            \(record.ism_secondary_accel_x),\
            \(record.ism_secondary_accel_y),\
            \(record.ism_secondary_accel_z),\
            \(record.ism_secondary_gyro_x),\
            \(record.ism_secondary_gyro_y),\
            \(record.ism_secondary_gyro_z),\
            \(record.lsm_accel_x),\
            \(record.lsm_accel_y),\
            \(record.lsm_accel_z),\
            \(record.lsm_gyro_x),\
            \(record.lsm_gyro_y),\
            \(record.lsm_gyro_z),\
            \(record.baro_alt),\
            \(record.gps_alt),\
            \"\(gpsFix)\",\
            \(record.gps_lat),\
            \(record.gps_lon),\
            \(record.gps_num_sats),\
            \(record.gps_utc_day),\
            \(record.gps_utc_hour),\
            \(record.gps_utc_itow),\
            \(record.gps_utc_min),\
            \(record.gps_utc_month),\
            \(record.gps_utc_nanos),\
            \(record.gps_utc_sec),\
            \(record.gps_utc_time_accuracy_estimate_ns),\
            \(record.gps_utc_valid),\
            \(record.gps_utc_year)
            """
            csvString.append(line + "\n")
        }

        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileURL = docsDir.appendingPathComponent("\(fileNamePrefix)-\(timestamp).csv")
        try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
