import Foundation

@Observable
final class PersonaStore: @unchecked Sendable {
    static let shared = PersonaStore()

    private static let defaultsKey = "customPersonas"

    private(set) var customPersonas: [Persona]

    var allPersonas: [Persona] {
        Persona.builtIn + customPersonas
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let personas = try? JSONDecoder().decode([Persona].self, from: data) {
            self.customPersonas = personas
        } else {
            self.customPersonas = []
        }
    }

    func add(_ persona: Persona) {
        var p = persona
        p.isBuiltIn = false
        customPersonas.append(p)
        persist()
    }

    func update(_ persona: Persona) {
        guard let idx = customPersonas.firstIndex(where: { $0.id == persona.id }) else { return }
        customPersonas[idx] = persona
        persist()
    }

    func delete(_ persona: Persona) {
        customPersonas.removeAll { $0.id == persona.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(customPersonas) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}
