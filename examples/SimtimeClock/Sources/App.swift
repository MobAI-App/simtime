import SwiftUI

@main
struct SimtimeClockApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            WorldClockTab()
                .tabItem { Label("World", systemImage: "globe") }
            AlarmTab()
                .tabItem { Label("Alarm", systemImage: "alarm.fill") }
            StopwatchTab()
                .tabItem { Label("Stopwatch", systemImage: "stopwatch.fill") }
            TimerTab()
                .tabItem { Label("Timer", systemImage: "timer") }
        }
        .tint(.orange)
    }
}
