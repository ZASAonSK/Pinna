import Foundation
import Combine
import CoreBluetooth
import UIKit

/// Connection state shown to the user.
enum LinkState: Equatable {
    case bluetoothOff
    case unauthorized
    case searching          // looking for the buds
    case connecting
    case ready              // control path available
    case noControlPath      // connected, but this device has no Samsung data path
}

struct BatteryLevels: Equatable {
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var updated: Date?
    var isEmpty: Bool { left == nil && right == nil && caseLevel == nil }
}

/// A connectable device seen nearby, offered in the device picker.
struct NearbyDevice: Identifiable, Equatable {
    let id: UUID
    var name: String
    var rssi: Int
    var lastSeen: Date
    var likelyBuds: Bool
    var connectedToPhone: Bool
}

struct LogLine: Identifiable {
    let id = UUID()
    let date: Date
    let text: String
}

/// Owns Bluetooth: finds the user's buds, keeps a GATT link to Samsung's data
/// path, and exposes what the buds really report over BLE:
///
/// * **Control** — settings frames written to `A7A48311` are executed.
/// * **Battery** — Samsung advertisement (0x0075) + Battery Service (`180F`).
/// * **Volume** — LE Audio Volume Control Service (`1844`), live in both directions.
/// * **Model / firmware** — Device Information (`180A`).
///
/// The buds never answer on the data path (`A7A48322`): measured on SM-R630
/// with CCCD = 1 and every known query; Samsung routes replies to RFCOMM only
/// (docs/PROTOCOL.md). Settings shown in the app are therefore the last
/// values sent, kept by `SettingsStore`.
final class BudsController: NSObject, ObservableObject {
    static let dataPathService = CBUUID(string: "A7A473E9-19C6-491B-AEA6-7EA92B8F043A")
    static let dataPathRX = CBUUID(string: "A7A48311-19C6-491B-AEA6-7EA92B8F043A")   // phone → buds
    static let batteryService = CBUUID(string: "180F")
    static let batteryLevel = CBUUID(string: "2A19")
    static let deviceInfo = CBUUID(string: "180A")
    static let modelNumber = CBUUID(string: "2A24")
    static let firmware = CBUUID(string: "2A26")
    static let presentation = CBUUID(string: "2904")
    static let volumeService = CBUUID(string: "1844")
    static let volumeState = CBUUID(string: "2B7D")        // [volume 0…255, mute, change counter]
    static let volumeControlPoint = CBUUID(string: "2B7E") // [opcode, change counter, (volume)]

    @Published private(set) var state: LinkState = .searching
    @Published private(set) var deviceName: String?
    @Published private(set) var model: BudsModel = .unknown
    @Published private(set) var modelNumber: String?
    @Published private(set) var firmware: String?
    @Published private(set) var battery = BatteryLevels()
    @Published private(set) var volume: Int?
    @Published private(set) var muted = false
    @Published private(set) var nearby: [NearbyDevice] = []
    @Published private(set) var log: [LogLine] = []
    @Published private(set) var lastSendOK: Date?
    @Published private(set) var lastError: String?

    var canControl: Bool { state == .ready }
    var currentDeviceID: UUID? { peripheral?.identifier }
    var hasKnownDevice: Bool { knownID != nil }

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rx: CBCharacteristic?
    private var volumeControl: CBCharacteristic?
    private var volumeCounter: UInt8 = 0
    private var batteryRoles: [ObjectIdentifier: Int] = [:]  // 0x010D left, 0x010E right, 0x0110 case
    private var gattBattery: [Int: Int] = [:]
    private var advBattery = BatteryLevels()
    private var retryTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var token: Data? = UserDefaults.standard.data(forKey: "pinna.adv.token")
    private var knownID: UUID? = UserDefaults.standard.string(forKey: "pinna.peripheral").flatMap(UUID.init)
    /// When the current connect attempt was (re)issued.
    private var connectIssued: Date?
    /// iOS keeps re-establishing the link by itself after it drops (iOS 17+).
    private let connectOptions: [String: Any] = [CBConnectPeripheralOptionEnableAutoReconnect: true]

    override init() {
        super.init()
        if let name = UserDefaults.standard.string(forKey: "pinna.name") { deviceName = name }
        if let number = UserDefaults.standard.string(forKey: "pinna.model") {
            modelNumber = number
            model = BudsModel.detect(modelNumber: number, name: deviceName)
        }
        central = CBCentralManager(delegate: self, queue: .main)
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.resume()
        })
        observers.append(nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.central.stopScan()
        })
    }

    deinit {
        retryTimer?.invalidate()
        for o in observers { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - Control

    /// Writes one settings frame to the data path. Returns false if not ready.
    @discardableResult
    func send(_ command: BudsCommand) -> Bool {
        guard let p = peripheral, let rx = rx, state == .ready else {
            lastError = L("Earbuds are not connected")
            return false
        }
        let frame = FrameCodec.encode(id: command.id, payload: command.payload, legacy: model.legacyFrame)
        let type: CBCharacteristicWriteType = rx.properties.contains(.write) ? .withResponse : .withoutResponse
        p.writeValue(frame, for: rx, type: type)
        note("→ \(command.name) \(BudsFrame.hex(frame))")
        if type == .withoutResponse { lastSendOK = Date() }
        return true
    }

    /// Volume Control Point opcodes (Bluetooth VCS): 0 down, 1 up, 4 set absolute, 5 unmute, 6 mute.
    func stepVolume(up: Bool) { writeVolume([up ? 0x01 : 0x00, volumeCounter]) }
    func setVolume(_ value: Int) { writeVolume([0x04, volumeCounter, UInt8(max(0, min(255, value)))]) }
    func setMuted(_ on: Bool) { writeVolume([on ? 0x06 : 0x05, volumeCounter]) }

    private func writeVolume(_ bytes: [UInt8]) {
        guard let p = peripheral, let c = volumeControl else { return }
        p.writeValue(Data(bytes), for: c, type: .withResponse)
        note("→ volume \(BudsFrame.hex(Data(bytes)))")
    }

    // MARK: - Connection

    func reconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        peripheral = nil; rx = nil
        state = .searching
        resume()
    }

    /// Forget the remembered buds (e.g. when switching to another pair).
    func forget() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        peripheral = nil; rx = nil; token = nil; knownID = nil
        for key in ["pinna.adv.token", "pinna.peripheral", "pinna.name", "pinna.model"] { UserDefaults.standard.removeObject(forKey: key) }
        deviceName = nil; modelNumber = nil; model = .unknown; firmware = nil; volume = nil
        battery = BatteryLevels(); advBattery = BatteryLevels(); gattBattery = [:]
        state = .searching
        resume()
    }

    /// Connect to a device the user picked; it becomes the remembered pair.
    func connect(to id: UUID) {
        guard central.state == .poweredOn,
              let p = central.retrievePeripherals(withIdentifiers: [id]).first else { return }
        knownID = id
        UserDefaults.standard.set(id.uuidString, forKey: "pinna.peripheral")
        connect(p)
    }

    /// Refresh the picker list with devices already connected to the iPhone.
    func refreshNearby() {
        guard central.state == .poweredOn else { return }
        startScan()
        for p in central.retrieveConnectedPeripherals(withServices: [Self.dataPathService, Self.batteryService]) {
            upsertNearby(id: p.identifier, name: p.name ?? L("Unnamed"), rssi: 0, connected: true)
        }
    }

    var logText: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
        let header = "\(AppInfo.name) \(AppInfo.version) • \(model.name) \(modelNumber ?? "-") fw \(firmware ?? "-") • \(state)"
        return ([header] + log.map { "[\(f.string(from: $0.date))] \($0.text)" }).joined(separator: "\n")
    }

    // MARK: - Internals

    private func note(_ text: String) {
        log.append(LogLine(date: Date(), text: text))
        if log.count > 500 { log.removeFirst(log.count - 500) }
    }

    private func resume() {
        guard central.state == .poweredOn else { return }
        startScan()
        if peripheral == nil { findConnectedBuds() }
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            guard let self = self, self.central.state == .poweredOn,
                  UIApplication.shared.applicationState == .active else { return }
            if self.peripheral == nil {
                self.findConnectedBuds()
            } else if self.state == .connecting, let issued = self.connectIssued, Date().timeIntervalSince(issued) > 20 {
                // After Bluetooth is toggled or the case is reopened a pending
                // connect can go stale; issue a fresh one.
                self.reissueConnect(reason: "still connecting after 20 s")
            }
        }
        watchConnectionEvents()
    }

    /// iOS reports when the buds connect to the phone (e.g. audio after the
    /// case is opened); that is the moment to bring up our LE link too.
    private func watchConnectionEvents() {
        guard let id = knownID else { return }
        central.registerForConnectionEvents(options: [.peripheralUUIDs: [id]])
    }

    /// Cancel the pending attempt and start a new one on a fresh handle.
    private func reissueConnect(reason: String) {
        guard central.state == .poweredOn, state != .ready, let id = knownID ?? peripheral?.identifier else { return }
        if let issued = connectIssued, Date().timeIntervalSince(issued) < 5 { return }
        note("Reconnecting (\(reason))")
        if let old = peripheral { central.cancelPeripheralConnection(old) }
        let fresh = central.retrieveConnectedPeripherals(withServices: [Self.dataPathService, Self.batteryService])
            .first(where: { $0.identifier == id }) ?? central.retrievePeripherals(withIdentifiers: [id]).first
        guard let p = fresh else { return }
        peripheral = p
        p.delegate = self
        state = .connecting
        connectIssued = Date()
        central.connect(p, options: connectOptions)
    }

    private func startScan() {
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    /// Only Samsung buds expose the data path service, so any match is a pair
    /// of buds even when the user renamed them.
    private func findConnectedBuds() {
        let withDataPath = central.retrieveConnectedPeripherals(withServices: [Self.dataPathService])
        let withBattery = central.retrieveConnectedPeripherals(withServices: [Self.batteryService])
            .filter { $0.identifier == knownID || BudsModel.looksLikeBuds($0.name) }
        let candidates = withDataPath + withBattery
        if let p = candidates.first(where: { $0.identifier == knownID }) ?? candidates.first {
            connect(p)
        } else if let id = knownID, let p = central.retrievePeripherals(withIdentifiers: [id]).first {
            connect(p)
        }
    }

    private func connect(_ p: CBPeripheral) {
        // A second connect to the same buds would cancel the pending one.
        if let current = peripheral, current.identifier == p.identifier, state == .connecting || state == .ready { return }
        if let old = peripheral, old.identifier != p.identifier { central.cancelPeripheralConnection(old) }
        peripheral = p
        p.delegate = self
        state = .connecting
        connectIssued = Date()
        note("Connecting to \(p.name ?? p.identifier.uuidString)")
        central.connect(p, options: connectOptions)
    }

    private func upsertNearby(id: UUID, name: String, rssi: Int, connected: Bool, audioHint: Bool = false) {
        let likely = BudsModel.looksLikeBuds(name) || id == knownID || connected || audioHint
        if let i = nearby.firstIndex(where: { $0.id == id }) {
            nearby[i].name = name
            if rssi != 0 { nearby[i].rssi = rssi }
            nearby[i].lastSeen = Date()
            nearby[i].likelyBuds = nearby[i].likelyBuds || likely
            nearby[i].connectedToPhone = nearby[i].connectedToPhone || connected
        } else {
            nearby.append(NearbyDevice(id: id, name: name, rssi: rssi, lastSeen: Date(), likelyBuds: likely, connectedToPhone: connected))
        }
        nearby.sort { ($0.likelyBuds ? 1 : 0, $0.rssi) > ($1.likelyBuds ? 1 : 0, $1.rssi) }
        if nearby.count > 40 { nearby.removeLast(nearby.count - 40) }
    }

    private func publishBattery() {
        var merged = advBattery
        if let l = gattBattery[0x010D] { merged.left = l }
        if let r = gattBattery[0x010E] { merged.right = r }
        if let c = gattBattery[0x0110] { merged.caseLevel = c }
        if !gattBattery.isEmpty { merged.updated = Date() }
        if merged != battery { battery = merged }
    }
}

// MARK: - CBCentralManagerDelegate

extension BudsController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if state == .bluetoothOff || state == .unauthorized { state = .searching }
            resume()
        case .unauthorized:
            state = .unauthorized
        default:
            state = .bluetoothOff
            peripheral = nil; rx = nil
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral, advertisementData a: [String: Any], rssi: NSNumber) {
        let manufacturer = a[CBAdvertisementDataManufacturerDataKey] as? Data
        let connectable = (a[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
        if connectable, let name = (a[CBAdvertisementDataLocalNameKey] as? String) ?? p.name, !name.isEmpty {
            // Renamed buds still advertise Samsung (0x0075) or Swift Pair (0x0006, 03) data.
            let m = [UInt8](manufacturer ?? Data())
            let hint = m.count >= 3 && ((m[0] == 0x75 && m[1] == 0x00) || (m[0] == 0x06 && m[1] == 0x00 && m[2] == 0x03))
            upsertNearby(id: p.identifier, name: name, rssi: rssi.intValue, connected: false, audioHint: hint)
            if peripheral == nil, p.identifier == knownID { connect(p) }
        }
        guard let data = manufacturer, AdvertisementDecoder.isBudsFrame(data) else { return }
        let tokens = token.map { [$0] } ?? []
        guard let decoded = AdvertisementDecoder.decode(data, tokens: tokens), decoded.hasBatteryValues else { return }
        if token == nil, let t = decoded.token, rssi.intValue > -75 {
            token = t
            UserDefaults.standard.set(t, forKey: "pinna.adv.token")
        }
        guard decoded.token == nil || decoded.token == token else { return }
        // Our buds are awake and advertising: a good moment to retry.
        if state == .connecting, let issued = connectIssued, Date().timeIntervalSince(issued) > 10 {
            reissueConnect(reason: "buds advertising")
        }
        var b = advBattery
        if let v = decoded.a { b.left = v }
        if let v = decoded.b { b.right = v }
        if let v = decoded.caseLevel { b.caseLevel = v }
        b.updated = Date()
        advBattery = b
        if let id = AdvertisementDecoder.modelColorID(data), model == .unknown {
            model = BudsModel.detect(colorID: id)
        }
        publishBattery()
    }

    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        guard p.identifier == peripheral?.identifier else { return }
        peripheral = p
        p.delegate = self
        connectIssued = nil
        knownID = p.identifier
        watchConnectionEvents()
        UserDefaults.standard.set(p.identifier.uuidString, forKey: "pinna.peripheral")
        if let name = p.name {
            deviceName = name
            UserDefaults.standard.set(name, forKey: "pinna.name")
        }
        note("Connected to \(p.name ?? "?")")
        rx = nil; batteryRoles.removeAll(); gattBattery.removeAll()
        p.discoverServices([Self.dataPathService, Self.batteryService, Self.deviceInfo, Self.volumeService])
    }

    func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for p: CBPeripheral) {
        guard event == .peerConnected, p.identifier == knownID, state != .ready else { return }
        note("Earbuds connected to the phone")
        reissueConnect(reason: "earbuds connected to the phone")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        guard p.identifier == peripheral?.identifier else { return }
        note("Connection failed: \(error?.localizedDescription ?? "-")")
        peripheral = nil
        state = .searching
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        guard p.identifier == peripheral?.identifier else { return }
        note("Disconnected\(error.map { ": \($0.localizedDescription)" } ?? "")")
        rx = nil; volumeControl = nil; volume = nil; gattBattery.removeAll()
        publishBattery()
        if central.state == .poweredOn {
            // Reconnect right away; iOS completes it when the buds are back.
            state = .connecting
            connectIssued = Date()
            central.connect(p, options: connectOptions)
        } else {
            peripheral = nil
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BudsController: CBPeripheralDelegate {
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        let services = p.services ?? []
        if !services.contains(where: { $0.uuid == Self.dataPathService }) {
            state = .noControlPath
            note("No Samsung data channel on this device")
        }
        for s in services { p.discoverCharacteristics(nil, for: s) }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for c in s.characteristics ?? [] {
            switch (s.uuid, c.uuid) {
            case (Self.dataPathService, Self.dataPathRX):
                rx = c
                state = .ready
                note("Control ready")
            case (Self.batteryService, Self.batteryLevel):
                p.discoverDescriptors(for: c)
                p.readValue(for: c)
                p.setNotifyValue(true, for: c)
            case (Self.deviceInfo, Self.modelNumber), (Self.deviceInfo, Self.firmware):
                p.readValue(for: c)
            case (Self.volumeService, Self.volumeState):
                p.readValue(for: c)
                p.setNotifyValue(true, for: c)
            case (Self.volumeService, Self.volumeControlPoint):
                volumeControl = c
            default:
                break
            }
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverDescriptorsFor c: CBCharacteristic, error: Error?) {
        for d in c.descriptors ?? [] where d.uuid == Self.presentation { p.readValue(for: d) }
    }

    /// Battery Service instances are labelled by their 2904 description:
    /// 0x010D left, 0x010E right, 0x0110 case.
    func peripheral(_ p: CBPeripheral, didUpdateValueFor d: CBDescriptor, error: Error?) {
        guard d.uuid == Self.presentation, let c = d.characteristic, let data = d.value as? Data, data.count >= 7 else { return }
        let b = [UInt8](data)
        let role = Int(b[5]) | (Int(b[6]) << 8)
        batteryRoles[ObjectIdentifier(c)] = role
        if let v = c.value?.first, v <= 100 { gattBattery[role] = Int(v) }
        publishBattery()
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        guard error == nil, let data = c.value else { return }
        switch c.uuid {
        case Self.batteryLevel:
            if let role = batteryRoles[ObjectIdentifier(c)], let v = data.first, v <= 100 {
                gattBattery[role] = Int(v)
                publishBattery()
            }
        case Self.modelNumber:
            let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .controlCharacters.union(.whitespaces))
            modelNumber = text
            UserDefaults.standard.set(text, forKey: "pinna.model")
            model = BudsModel.detect(modelNumber: text, name: deviceName)
            note("Model \(text) → \(model.name)")
        case Self.firmware:
            firmware = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .controlCharacters.union(.whitespaces))
        case Self.volumeState:
            let b = [UInt8](data)
            if b.count >= 3 { volume = Int(b[0]); muted = b[1] != 0; volumeCounter = b[2] }
        default:
            break
        }
    }

    func peripheral(_ p: CBPeripheral, didWriteValueFor c: CBCharacteristic, error: Error?) {
        if c.uuid == Self.volumeControlPoint {
            if let e = error {
                // Usually a stale change counter: re-read the state and let the user retry.
                note("✕ volume: \(e.localizedDescription)")
                if let state = c.service?.characteristics?.first(where: { $0.uuid == Self.volumeState }) { p.readValue(for: state) }
            }
            return
        }
        guard c.uuid == Self.dataPathRX else { return }
        if let e = error {
            lastError = e.localizedDescription
            note("✕ write failed: \(e.localizedDescription)")
        } else {
            lastSendOK = Date()
            lastError = nil
        }
    }
}
