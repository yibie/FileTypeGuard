    import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("FileTypeGuard")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("tagline")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 10)
        }
        .frame(width: 400, height: 300)
        .padding()
    }
}

#Preview {
    ContentView()
}
