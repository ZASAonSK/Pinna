import Foundation

// 0.4.2: tolerant Samsung Buds "Easy Setup" framing.
//
// iOS concatenates manufacturer data from the advertising packet and the scan
// response into a single Data blob. For the inspected Buds3 Pro that is
// 26 + 13 = 39 bytes:
//
//   [75 00] [42 09 81 02 14 15 03 21 01 ... advertising tail ...]
//   [status] [6-byte set token] [case] [left] [right] [00] [variant] [variant]
//
// The trailing scan-response block carries the battery percentages (13 bytes
// when complete). The previous build required exactly 39 bytes plus a
// hard-coded token and suffix, and rejected the whole frame if any single
// percentage was >100, so an earbud out of the case (255) silently discarded
// everything. That is why values appeared only with the case open and both
// earbuds inside.
//
// This parser learns the 6-byte token from the first decoded frame and then
// accepts the same block at any position and with 1...6 values. Percentages
// stay independently optional: a value above 100 means "unavailable", never a
// confirmed sentinel, charging flag or in-ear flag.
struct AdvertisedBattery {
    let caseLevel: Int?
    let a: Int?
    let b: Int?
    /// First byte of the scan-response block. Semantics are not confirmed.
    let status: UInt8?
    /// Trailing three bytes of the scan-response block.
    let suffix: [UInt8]
    /// Device/set identity found in the scan-response block.
    let token: Data?
    /// Total manufacturer-data length reported by iOS (advertisement + scan response).
    let frameLength: Int
    /// Number of battery bytes found in the block, before percentage validation.
    let batteryCount: Int
    /// Value-region bytes exactly as received, including values above 100.
    /// Diagnostics only; `caseLevel`/`a`/`b` stay the decoded percentages.
    let rawValues: [UInt8]
    /// True when fewer than three battery bytes were present in the block.
    var partial: Bool { batteryCount < 3 }
    /// Number of channels with a plausible percentage (0...3).
    var validBatteryCount: Int { [caseLevel, a, b].compactMap { $0 }.count }
    var hasBatteryValues: Bool { caseLevel != nil || a != nil || b != nil }
    /// Complete manufacturer-data blob in hex. Used by scenario comparison:
    /// a single status byte does not change in the user's captures.
    let frameHex: String
}

enum AdvertisementDecoder {
    static let companyID: [UInt8] = [0x75, 0x00]
    static let easySetupPrefix: [UInt8] = [0x42, 0x09, 0x81, 0x02, 0x14, 0x15, 0x03, 0x21, 0x01]
    static let tokenLength = 6
    static let suffixLength = 3
    static let canonicalFullLength = 39
    static let canonicalBlockLength = 13
    /// Offset of the scan-response block when the advertising payload keeps its
    /// observed 26-byte length. A shortened scan response still starts here.
    static let canonicalBlockOffset = 26

    /// Samsung manufacturer data with the Buds Easy Setup header, regardless of
    /// whether this particular frame still contains battery bytes.
    /// Samsung model+colour id carried in the Easy Setup advertisement
    /// (big-endian at offset 14, e.g. 0x0154 = 340 = Buds3 Pro Silver).
    static func modelColorID(_ data: Data) -> Int? {
        let b = [UInt8](data)
        guard b.count >= 16, isBudsFrame(data) else { return nil }
        return (Int(b[14]) << 8) | Int(b[15])
    }

    static func isBudsFrame(_ data: Data) -> Bool {
        let b = [UInt8](data)
        guard b.count >= 2 + easySetupPrefix.count + 1 else { return false }
        return Array(b[0..<2]) == companyID && Array(b[2..<(2 + easySetupPrefix.count)]) == easySetupPrefix
    }

    /// Token learned from a complete, unmodified 39-byte frame or from a bare
    /// 13-byte scan-response block. Returns nil for advertising-only frames.
    static func learnedToken(from data: Data) -> Data? {
        let b = [UInt8](data)
        if b.count == canonicalFullLength, let token = blockToken(b, at: canonicalFullLength - canonicalBlockLength), blockIsValid(b, at: b.count - canonicalBlockLength, strictSuffix: true) {
            return token
        }
        if b.count == canonicalBlockLength, blockIsValid(b, at: 0, strictSuffix: true) {
            return blockToken(b, at: 0)
        }
        return nil
    }

    static func decode(_ data: Data, tokens: [Data] = []) -> AdvertisedBattery? {
        let b = [UInt8](data)
        guard isBudsFrame(data) else { return nil }

        var blockStart: Int?
        var matchedToken: Data?
        var matchedByToken = false

        // Preferred path: the learned identity can appear anywhere in the blob,
        // so a changed block length or a different merge order still decodes.
        // Try every occurrence and keep the first one whose value region has a
        // plausible length; a coincidental match in the advertising tail must
        // not hide the real block near the end of the blob.
        for token in tokens where token.count == tokenLength {
            let needle = [UInt8](token)
            var searchFrom = 1
            while let tokenStart = find(needle, in: b, from: searchFrom), tokenStart >= 1 {
                let candidate = tokenStart - 1
                let count = (b.count - suffixLength) - (candidate + 1 + tokenLength)
                if count >= 1, count <= 6 {
                    blockStart = candidate
                    matchedToken = token
                    matchedByToken = true
                    break
                }
                searchFrom = tokenStart + 1
            }
            if blockStart != nil { break }
        }

        // No learned identity yet: accept the bare block, or a shortened scan
        // response (37...39 bytes) that keeps the block at the observed
        // 26-byte offset. Longer/shifted blobs wait for a learned token.
        if blockStart == nil {
            if b.count == canonicalBlockLength, blockIsValid(b, at: 0, strictSuffix: true) {
                blockStart = 0
            } else if b.count >= canonicalBlockOffset + 1 + tokenLength + 1 + suffixLength,
                      b.count <= canonicalFullLength,
                      blockIsValid(b, at: canonicalBlockOffset, strictSuffix: true) {
                blockStart = canonicalBlockOffset
            }
        }

        guard let start = blockStart, blockIsValid(b, at: start, strictSuffix: !matchedByToken) else { return nil }

        let token = matchedToken ?? blockToken(b, at: start)
        let status = b[start]
        let valueStart = start + 1 + tokenLength
        let valueEnd = b.count - suffixLength
        guard valueEnd >= valueStart else { return nil }
        let values = Array(b[valueStart..<valueEnd])
        guard values.count >= 1, values.count <= 6 else { return nil }

        func percent(_ raw: UInt8) -> Int? { raw <= 100 ? Int(raw) : nil }

        var caseLevel: Int?
        var a: Int?
        var bLevel: Int?
        if values.count >= 1 { caseLevel = percent(values[0]) }
        if values.count >= 2 { a = percent(values[1]) }
        if values.count >= 3 { bLevel = percent(values[2]) }
        let frameHex = b.map { String(format: "%02X", $0) }.joined(separator: " ")

        return AdvertisedBattery(
            caseLevel: caseLevel,
            a: a,
            b: bLevel,
            status: status,
            suffix: Array(b[valueEnd..<b.count]),
            token: token,
            frameLength: b.count,
            batteryCount: values.count,
            rawValues: values,
            frameHex: frameHex
        )
    }

    /// Unverified hypothesis, diagnostics only: some earbuds encode "charging"
    /// in bit 7 of the same byte, so `0x80 | percent` means "percent, charging".
    /// Buds3 Pro frames observed so far only carry 0...100 and 255, so this is
    /// never used for the displayed values until a real charging frame confirms
    /// it. 0xFF (255) is deliberately excluded: it stays "unavailable".
    static func chargingCandidate(_ raw: UInt8) -> Int? {
        guard raw >= 0x80, raw <= 0xE4 else { return nil }
        return Int(raw & 0x7F)
    }

    private static func blockToken(_ b: [UInt8], at start: Int) -> Data? {
        let tokenStart = start + 1
        let tokenEnd = tokenStart + tokenLength
        guard tokenEnd <= b.count else { return nil }
        return Data(b[tokenStart..<tokenEnd])
    }

    /// A block is accepted when it has a status byte, a token, at least one
    /// value and a suffix whose first byte is zero. This is the only structural
    /// constraint kept from the original exact-layout build.
    private static func blockIsValid(_ b: [UInt8], at start: Int, strictSuffix: Bool) -> Bool {
        let minimum = 1 + tokenLength + 1 + suffixLength
        guard start >= 0, start + minimum <= b.count else { return false }
        let suffixStart = b.count - suffixLength
        guard suffixStart > start + 1 + tokenLength else { return false }
        return strictSuffix ? b[suffixStart] == 0x00 : true
    }

    private static func find(_ needle: [UInt8], in haystack: [UInt8], from: Int) -> Int? {
        guard !needle.isEmpty, haystack.count >= needle.count else { return nil }
        var index = max(0, from)
        while index + needle.count <= haystack.count {
            if Array(haystack[index..<(index + needle.count)]) == needle { return index }
            index += 1
        }
        return nil
    }
}
