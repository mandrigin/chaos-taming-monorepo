import SwiftUI

struct ContentView: View {
    @Binding var document: InputForgeDocument

    var body: some View {
        VStack {
            Image(systemName: "hammer.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("InputForge")
                .font(.title)
            Text("Document ready")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}
