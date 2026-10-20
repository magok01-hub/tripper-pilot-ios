import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var tripper: TripperBluetoothController
    @State private var pin = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tripper Pod") {
                    LabeledContent("Estado", value: tripper.status)
                    LabeledContent("Bluetooth", value: tripper.bluetoothState)

                    Button(tripper.isRunning ? "Parar busca" : "Buscar e conectar") {
                        tripper.isRunning ? tripper.stop() : tripper.start()
                    }
                }

                Section("Primeiro pareamento") {
                    TextField("PIN mostrado no Tripper", text: $pin)
                        .keyboardType(.numberPad)
                    Button("Enviar PIN") {
                        tripper.submit(pin: pin)
                    }
                    .disabled(pin.isEmpty || !tripper.isConnected)
                }

                Section("Diagnóstico") {
                    Button("Iniciar pareamento") {
                        tripper.requestPairing()
                    }
                    .disabled(!tripper.isConnected)

                    Button("Retomar dispositivo conhecido") {
                        tripper.resumeKnownDevice()
                    }
                    .disabled(!tripper.isConnected)

                    Button("Enviar keepalive") {
                        tripper.sendKeepalive()
                    }
                    .disabled(!tripper.isConnected)
                }

                Section("Registro") {
                    if tripper.events.isEmpty {
                        Text("Os eventos Bluetooth aparecerão aqui.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tripper.events.reversed(), id: \.self) { event in
                            Text(event)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("Tripper Pilot")
        }
    }
}

