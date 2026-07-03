import Combine
import CoreBluetooth
import Foundation
import SwiftProtobuf

struct CameraPeripheral: Identifiable {
    let peripheral: CBPeripheral
    let rssi: NSNumber

    var id: UUID { peripheral.identifier }
    var name: String { peripheral.name ?? "RocketCam" }
}

final class CameraControlService: NSObject, ObservableObject {
    @Published private(set) var discoveredDevices: [CameraPeripheral] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isConnected = false
    @Published private(set) var cameraConfig: SG2CameraConfig?
    @Published private(set) var statusMessage = "Not connected"

    private var centralManager: CBCentralManager!
    private var connectedDevice: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var shouldScanWhenPoweredOn = false
    private var sequence: UInt32 = 0

    private let serviceUUID = CBUUID(string: "9A8B0001-7C6D-4B2A-9E3F-1C2D3E4F5060")
    private let commandUUID = CBUUID(string: "9A8B0002-7C6D-4B2A-9E3F-1C2D3E4F5060")
    private let statusUUID = CBUUID(string: "9A8B0003-7C6D-4B2A-9E3F-1C2D3E4F5060")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        shouldScanWhenPoweredOn = true
        guard centralManager.state == .poweredOn else {
            statusMessage = "Waiting for Bluetooth"
            return
        }

        discoveredDevices.removeAll()
        isScanning = true
        statusMessage = "Scanning for RocketCam"
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScanning() {
        shouldScanWhenPoweredOn = false
        isScanning = false
        centralManager.stopScan()
    }

    func connect(to camera: CameraPeripheral) {
        stopScanning()
        statusMessage = "Connecting to \(camera.name)"
        connectedDevice = camera.peripheral
        camera.peripheral.delegate = self
        centralManager.connect(camera.peripheral, options: nil)
    }

    func disconnect() {
        if let connectedDevice {
            centralManager.cancelPeripheralConnection(connectedDevice)
        }
        resetConnectionState(message: "Not connected")
    }

    func requestStatus() {
        var command = SG2CameraCommand()
        command.requestStatus = true
        write(command)
    }

    func setBand(_ band: SG2VtxBand, channel: UInt32) {
        var command = SG2CameraCommand()
        command.band = band
        command.channel = channel
        command.requestStatus = true
        write(command)
    }

    func setPower(_ power: SG2VtxPowerLevel) {
        var command = SG2CameraCommand()
        command.power = power
        command.requestStatus = true
        write(command)
    }

    func setRFEnabled(_ enabled: Bool) {
        var command = SG2CameraCommand()
        command.rfEnabled = enabled
        command.requestStatus = true
        write(command)
    }

    func setCameraRecording(_ recording: Bool) {
        var command = SG2CameraCommand()
        command.cameraRecord = recording
        command.requestStatus = true
        write(command)
    }

    private func write(_ command: SG2CameraCommand) {
        guard isConnected,
              let connectedDevice,
              let commandCharacteristic else {
            statusMessage = "Connect to RocketCam first"
            return
        }

        sequence &+= 1
        var envelope = SG2Envelope()
        envelope.nodeSrc = .nodeMobileNode1
        envelope.nodeDst = .nodeRocketCam
        envelope.seq = sequence
        envelope.timestampMs = UInt64(Date().timeIntervalSince1970 * 1000)
        envelope.camCommand = command

        do {
            let data = try envelope.serializedData()
            connectedDevice.writeValue(data, for: commandCharacteristic, type: .withResponse)
            statusMessage = "Command sent"
        } catch {
            statusMessage = "Could not encode command"
        }
    }

    private func handleStatusData(_ data: Data) {
        do {
            let envelope = try SG2Envelope(serializedBytes: data)
            switch envelope.payload {
            case .camConfig(let config):
                cameraConfig = config
                statusMessage = "Status updated"
            case .ack(let ack):
                statusMessage = ack.ok ? "Command accepted" : "Command rejected: \(ack.message)"
            default:
                break
            }
        } catch {
            statusMessage = "Could not decode camera status"
        }
    }

    private func resetConnectionState(message: String) {
        isConnected = false
        connectedDevice = nil
        commandCharacteristic = nil
        statusCharacteristic = nil
        cameraConfig = nil
        statusMessage = message
    }
}

extension CameraControlService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth ready"
            if shouldScanWhenPoweredOn {
                startScanning()
            }
        case .poweredOff:
            resetConnectionState(message: "Bluetooth is off")
            isScanning = false
        case .unauthorized:
            resetConnectionState(message: "Bluetooth is not authorized")
            isScanning = false
        case .unsupported:
            resetConnectionState(message: "Bluetooth is not supported")
            isScanning = false
        case .resetting:
            statusMessage = "Bluetooth is resetting"
        case .unknown:
            statusMessage = "Bluetooth state unknown"
        @unknown default:
            statusMessage = "Bluetooth unavailable"
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let deviceName = advertisedName ?? peripheral.name

        guard advertisedServices.contains(serviceUUID) || deviceName == "RocketCam" else {
            return
        }

        let camera = CameraPeripheral(peripheral: peripheral, rssi: RSSI)
        if let index = discoveredDevices.firstIndex(where: { $0.id == camera.id }) {
            discoveredDevices[index] = camera
        } else {
            discoveredDevices.append(camera)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusMessage = "Discovering camera service"
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        resetConnectionState(message: error?.localizedDescription ?? "Could not connect")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        resetConnectionState(message: error?.localizedDescription ?? "Disconnected")
    }
}

extension CameraControlService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            resetConnectionState(message: error.localizedDescription)
            return
        }

        guard let cameraService = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            resetConnectionState(message: "RocketCam service not found")
            return
        }

        peripheral.discoverCharacteristics([commandUUID, statusUUID], for: cameraService)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            resetConnectionState(message: error.localizedDescription)
            return
        }

        service.characteristics?.forEach { characteristic in
            if characteristic.uuid == commandUUID {
                commandCharacteristic = characteristic
            } else if characteristic.uuid == statusUUID {
                statusCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
            }
        }

        if commandCharacteristic != nil, statusCharacteristic != nil {
            isConnected = true
            statusMessage = "Connected to RocketCam"
            requestStatus()
        } else {
            resetConnectionState(message: "Camera characteristics not found")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            statusMessage = error.localizedDescription
            return
        }

        guard characteristic.uuid == statusUUID, let data = characteristic.value else { return }
        handleStatusData(data)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            statusMessage = error.localizedDescription
            return
        }
        statusMessage = "Command delivered"
        if let statusCharacteristic {
            peripheral.readValue(for: statusCharacteristic)
        }
    }
}
