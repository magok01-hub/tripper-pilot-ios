import CoreBluetooth
import Foundation

final class TripperBluetoothController: NSObject, ObservableObject {
    static let serviceUUID = CBUUID(string: "01FF0100-BA5E-F4EE-5CA1-EB1E5E4B1CE0")
    static let characteristicUUID = CBUUID(string: "01FF0101-BA5E-F4EE-5CA1-EB1E5E4B1CE0")

    @Published private(set) var status = "Parado"
    @Published private(set) var bluetoothState = "Desconhecido"
    @Published private(set) var isRunning = false
    @Published private(set) var isConnected = false
    @Published private(set) var events: [String] = []

    private var central: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var pod: CBPeripheral?
    private var writableCharacteristic: CBCharacteristic?
    private var localCharacteristic: CBMutableCharacteristic?
    private var keepaliveTimer: Timer?

    override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "br.com.magok01.tripperpilot.central"]
        )
        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: .main,
            options: [CBPeripheralManagerOptionRestoreIdentifierKey: "br.com.magok01.tripperpilot.peripheral"]
        )
    }

    func start() {
        isRunning = true
        guard central.state == .poweredOn else {
            status = "Aguardando Bluetooth"
            return
        }
        beginScan()
    }

    func stop() {
        isRunning = false
        central.stopScan()
        keepaliveTimer?.invalidate()
        if let pod { central.cancelPeripheralConnection(pod) }
        status = "Parado"
    }

    func requestPairing() { send(TripperPacket.handshakeShowPIN, label: "handshake novo") }
    func resumeKnownDevice() { send(TripperPacket.handshakeResume, label: "handshake conhecido") }
    func sendKeepalive() { send(TripperPacket.keepalive, label: "keepalive") }

    func submit(pin: String) {
        guard let packet = TripperPacket.pin(pin) else {
            log("PIN inválido")
            return
        }
        send(packet, label: "PIN")
    }

    private func beginScan() {
        status = "Procurando RE_DISP"
        log("Busca iniciada")
        central.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func publishLocalService() {
        guard peripheralManager.state == .poweredOn else { return }
        peripheralManager.removeAllServices()
        let characteristic = CBMutableCharacteristic(
            type: Self.characteristicUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [characteristic]
        localCharacteristic = characteristic
        peripheralManager.add(service)
    }

    private func send(_ data: Data, label: String) {
        guard let pod, let characteristic = writableCharacteristic else {
            log("Não enviado: \(label), característica indisponível")
            return
        }
        let type: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse)
            ? .withoutResponse
            : .withResponse
        pod.writeValue(data, for: characteristic, type: type)
        log("TX \(label): \(data.hex)")
    }

    private func startKeepalive() {
        keepaliveTimer?.invalidate()
        keepaliveTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.sendKeepalive()
        }
    }

    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        events.append("\(formatter.string(from: Date()))  \(message)")
        if events.count > 200 { events.removeFirst(events.count - 200) }
    }
}

extension TripperBluetoothController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state.label
        log("Central: \(bluetoothState)")
        if central.state == .poweredOn, isRunning { beginScan() }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let first = restored.first {
            pod = first
            first.delegate = self
            isRunning = true
            log("Estado central restaurado")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "sem nome"
        guard name == "RE_DISP" || peripheral.name == "RE_DISP" else { return }
        central.stopScan()
        pod = peripheral
        peripheral.delegate = self
        status = "Conectando"
        log("Encontrado \(name), RSSI \(RSSI)")
        // Algumas versões do iOS rejeitam EnableAutoReconnect na primeira
        // conexão com NSError "One or more parameters were invalid".
        // A reconexão continua sendo feita explicitamente no disconnect.
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        status = "Conectado; descobrindo serviço"
        log("Conectado")
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        status = "Falha ao conectar"
        log("Falha: \(errorDescription(error))")
        if isRunning { beginScan() }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        writableCharacteristic = nil
        status = "Desconectado; aguardando retorno"
        log("Desconectado: \(errorDescription(error))")
        if isRunning { central.connect(peripheral, options: nil) }
    }

    private func errorDescription(_ error: Error?) -> String {
        guard let error else { return "sem erro" }
        let nsError = error as NSError
        return "\(nsError.localizedDescription) [\(nsError.domain) \(nsError.code)]"
    }
}

extension TripperBluetoothController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            log("Erro serviços: \(error!.localizedDescription)")
            return
        }
        peripheral.services?.forEach { peripheral.discoverCharacteristics([Self.characteristicUUID], for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            log("Erro característica: \(error!.localizedDescription)")
            return
        }
        writableCharacteristic = service.characteristics?.first { $0.uuid == Self.characteristicUUID }
        guard writableCharacteristic != nil else {
            status = "Característica não encontrada"
            return
        }
        status = "Pronto para parear"
        log("Canal Tripper pronto")
        startKeepalive()
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { log("Erro TX: \(error.localizedDescription)") }
    }
}

extension TripperBluetoothController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        log("Servidor local: \(peripheral.state.label)")
        if peripheral.state == .poweredOn { publishLocalService() }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        if let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService],
           let characteristic = services.first?.characteristics?.first as? CBMutableCharacteristic {
            localCharacteristic = characteristic
            log("Estado periférico restaurado")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error { log("Erro servidor local: \(error.localizedDescription)") }
        else { log("Servidor GATT local publicado") }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let value = request.value { log("RX: \(value.hex)") }
            peripheral.respond(to: request, withResult: .success)
        }
    }
}

private extension CBManagerState {
    var label: String {
        switch self {
        case .unknown: "Desconhecido"
        case .resetting: "Reiniciando"
        case .unsupported: "Não suportado"
        case .unauthorized: "Não autorizado"
        case .poweredOff: "Desligado"
        case .poweredOn: "Ligado"
        @unknown default: "Outro"
        }
    }
}

private extension Data {
    var hex: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}


