//☎️
import SwiftUI
struct PhilosophicalIconSet: View {
    var body: some View {
        HStack(spacing: 40) {
            // Elevated Scroll: Dazzling gold highlight with neumorphic circle
            Image(systemName: "arrowtriangle.up")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(.sRGB, red: 1.00, green: 0.84, blue: 0.00), location: 0.0),
                            .init(color: Color(.sRGB, red: 1.00, green: 0.92, blue: 0.16), location: 0.5),
                            .init(color: Color(.sRGB, red: 1.00, green: 0.84, blue: 0.00), location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(20)
                .neumorphic(cornerRadius: 40)
            // Bad Scale Mass: Crimson → Charcoal gradient with neumorphic circle
            Image(systemName: "arrowtriangle.down")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(.sRGB, red: 0.86, green: 0.08, blue: 0.24), // #DC143C
                            Color(.sRGB, red: 0.17, green: 0.17, blue: 0.17)  // #2C2C2C
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(20)
                .neumorphic(cornerRadius: 40)
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }
}
struct PhilosophicalIconSet_Previews: PreviewProvider {
    static var previews: some View {
        PhilosophicalIconSet()
    }
}



