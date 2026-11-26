import Foundation

/// One Galaxy Buds message: `SOM | size (2 B LE) | id | payload | CRC16 (LE) | EOM`.
///
/// `size & 0x3FF` = 1 (id) + payload + 2 (CRC). Bit 0x1000 marks a *response*
/// (Samsung's manager uses it to acknowledge unsolicited messages from the
/// buds), bit 0x2000 a fragment. Settings are sent without either bit.
/// CRC-16/XMODEM (poly 0x1021, init 0, no reflection) over `id + payload`.
/// Verified against frames captured from SM-R630 over RFCOMM and against the
/// encoder in Samsung's Galaxy Buds3 Pro Manager (`f8.a.e()`).
struct BudsFrame: Equatable {
    let id: UInt8
    let payload: Data
    var isResponse = false

    var hex: String { BudsFrame.hex(payload) }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

enum FrameCodec {
    /// Buds+ and newer.
    static let som: UInt8 = 0xFD
    static let eom: UInt8 = 0xDD
    /// First-generation Galaxy Buds (2019).
    static let legacySom: UInt8 = 0xFE
    static let legacyEom: UInt8 = 0xEE

    private static let table: [UInt16] = (0..<256).map { i -> UInt16 in
        var v = UInt16(i) << 8
        for _ in 0..<8 { v = (v & 0x8000) != 0 ? (v << 1) ^ 0x1021 : v << 1 }
        return v
    }

    static func crc16(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0
        for b in bytes { crc = table[Int(((crc >> 8) ^ UInt16(b)) & 0xFF)] ^ (crc << 8) }
        return crc
    }

    static func encode(id: UInt8, payload: Data = Data(), response: Bool = false, legacy: Bool = false) -> Data {
        let body = [id] + [UInt8](payload)
        let crc = crc16(body)
        let size = body.count + 2
        var hi = UInt8((size >> 8) & 0x03)
        if response { hi |= 0x10 }
        var out = Data([legacy ? legacySom : som, UInt8(size & 0xFF), hi])
        out.append(contentsOf: body)
        out.append(UInt8(crc & 0xFF))
        out.append(UInt8(crc >> 8))
        out.append(legacy ? legacyEom : eom)
        return out
    }

    private static func end(for start: UInt8) -> UInt8? {
        switch start {
        case som: return eom
        case legacySom: return legacyEom
        default: return nil
        }
    }

    /// Strict single-frame decoder (wrong markers, size or CRC → nil).
    static func decode(_ data: Data) -> BudsFrame? {
        let b = [UInt8](data)
        guard b.count >= 6, let e = end(for: b[0]), b[b.count - 1] == e, b[2] & 0x20 == 0 else { return nil }
        let size = (Int(b[1]) | (Int(b[2]) << 8)) & 0x03FF
        guard size >= 3, b.count == size + 4 else { return nil }
        let payload = Data(b[4..<(1 + size)])
        let crc = UInt16(b[1 + size]) | (UInt16(b[2 + size]) << 8)
        guard crc16([b[3]] + [UInt8](payload)) == crc else { return nil }
        return BudsFrame(id: b[3], payload: payload, isResponse: b[2] & 0x10 != 0)
    }
}
