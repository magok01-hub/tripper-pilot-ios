import Foundation

enum TripperPacket {
    static let handshakeShowPIN = Data([
        0x21, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x50, 0xA7
    ])

    static let handshakeResume = Data([
        0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x45
    ])

    static let keepalive = Data([
        0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x45, 0xD9
    ])

    static func pin(_ value: String) -> Data? {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty, digits.count <= 6 else { return nil }

        var payload = [UInt8](repeating: 0, count: 18)
        payload[0] = 0x20
        for (index, byte) in digits.utf8.enumerated() {
            payload[index + 1] = byte
        }
        return framed(payload)
    }

    static func setTime(_ date: Date = Date(), calendar: Calendar = .current) -> Data {
        var payload = [UInt8](repeating: 0, count: 18)
        payload[0] = 0x50
        payload[1] = UInt8(calendar.component(.hour, from: date))
        payload[2] = UInt8(calendar.component(.minute, from: date))
        return framed(payload)
    }

    static func framed(_ payload: [UInt8]) -> Data {
        precondition(payload.count == 18)
        let crc = crc16(payload)
        return Data(payload + [UInt8(crc >> 8), UInt8(crc & 0xFF)])
    }

    static func crc16(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return crc
    }
}

