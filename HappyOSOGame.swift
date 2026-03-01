import SwiftUI
import Combine

// MARK: - Game Constants
struct GameConstants {
    static let gravity: CGFloat = 0.38
    static let jumpVelocity: CGFloat = -9.0
    static let pipeSpeed: CGFloat = 2.8
    static let pipeWidth: CGFloat = 72
    static let pipeGap: CGFloat = 220
    static let pipeSpawnInterval: TimeInterval = 2.3
    static let osoSize: CGFloat = 160}

// MARK: - Pipe Model
struct Pipe: Identifiable {
    let id = UUID()
    var x: CGFloat
    let gapY: CGFloat
    var scored: Bool = false
}

// MARK: - Game State
enum GameState {
    case waiting, playing, gameOver
}

// MARK: - Game ViewModel
class GameViewModel: ObservableObject {
    @Published var osoY: CGFloat = 300
    @Published var osoVelocity: CGFloat = 0
    @Published var osoRotation: Double = 0
    @Published var pipes: [Pipe] = []
    @Published var score: Int = 0
    @Published var highScore: Int = 0
    @Published var gameState: GameState = .waiting
    @Published var showScorePopup: Bool = false
    @Published var cloudOffset: CGFloat = 0

    private var timer: AnyCancellable?
    private var pipeTimer: AnyCancellable?
    private var cloudTimer: AnyCancellable?
    private var screenWidth: CGFloat = 390
    private var screenHeight: CGFloat = 844

    func setup(width: CGFloat, height: CGFloat) {
        screenWidth = width
        screenHeight = height
        osoY = height / 2
        startClouds()
    }

    private func startClouds() {
        cloudTimer = Timer.publish(every: 1/60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.cloudOffset -= 0.35
                if self.cloudOffset < -self.screenWidth { self.cloudOffset = 0 }
            }
    }

    func tap() {
        switch gameState {
        case .waiting: startGame(); jump()
        case .playing: jump()
        case .gameOver: resetGame()
        }
    }

    private func jump() {
        osoVelocity = GameConstants.jumpVelocity
        withAnimation(.easeOut(duration: 0.08)) { osoRotation = -28 }
    }

    private func startGame() {
        gameState = .playing
        timer = Timer.publish(every: 1/60, on: .main, in: .common)
            .autoconnect().sink { [weak self] _ in self?.update() }
        pipeTimer = Timer.publish(every: GameConstants.pipeSpawnInterval, on: .main, in: .common)
            .autoconnect().sink { [weak self] _ in self?.spawnPipe() }
        spawnPipe()
    }

    private func stopTimers() {
        timer?.cancel()
        pipeTimer?.cancel()
    }

    private func update() {
        guard gameState == .playing else { return }

        osoVelocity += GameConstants.gravity
        osoY += osoVelocity

        let targetRotation = Double(min(max(osoVelocity * 4, -28), 75))
        osoRotation += (targetRotation - osoRotation) * 0.12

        for i in pipes.indices {
            pipes[i].x -= GameConstants.pipeSpeed
            let osoX = screenWidth * 0.28
            if !pipes[i].scored && pipes[i].x + GameConstants.pipeWidth < osoX {
                pipes[i].scored = true
                score += 1
                showScorePopup = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.showScorePopup = false }
            }
        }

        pipes.removeAll { $0.x + GameConstants.pipeWidth < 0 }

        let osoX = screenWidth * 0.28
        let r = GameConstants.osoSize / 2 - 70

        if osoY + r > screenHeight - 90 || osoY - r < 0 {
            triggerGameOver(); return
        }

        for pipe in pipes {
            let gapTop = pipe.gapY - GameConstants.pipeGap / 2
            let gapBottom = pipe.gapY + GameConstants.pipeGap / 2
            if osoX + r > pipe.x && osoX - r < pipe.x + GameConstants.pipeWidth {
                if osoY - r < gapTop || osoY + r > gapBottom {
                    triggerGameOver(); return
                }
            }
        }
    }

    private func spawnPipe() {
        let gapY = CGFloat.random(in: screenHeight * 0.26...screenHeight * 0.70)
        pipes.append(Pipe(x: screenWidth + 20, gapY: gapY))
    }

    private func triggerGameOver() {
        gameState = .gameOver
        stopTimers()
        if score > highScore { highScore = score }
    }

    private func resetGame() {
        osoY = screenHeight / 2
        osoVelocity = 0
        osoRotation = 0
        pipes = []
        score = 0
        gameState = .waiting
    }
}

// MARK: - OSO using real photo from Assets
struct OSOView: View {
    var rotation: Double

    var body: some View {
        Image("oso")
            .resizable()
            .scaledToFit()
            .frame(width: GameConstants.osoSize, height: GameConstants.osoSize)
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Nature Pipe (tree trunk with leafy caps)
struct NaturePipeView: View {
    let pipe: Pipe
    let screenHeight: CGFloat

    var trunkGrad: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.58, green: 0.37, blue: 0.15),
                     Color(red: 0.40, green: 0.24, blue: 0.08),
                     Color(red: 0.55, green: 0.34, blue: 0.13)],
            startPoint: .leading, endPoint: .trailing
        )
    }

    var leafColor: Color { Color(red: 0.22, green: 0.62, blue: 0.22) }
    var leafHighlight: Color { Color(red: 0.32, green: 0.75, blue: 0.32) }

    var body: some View {
        let topH = pipe.gapY - GameConstants.pipeGap / 2
        let botTop = pipe.gapY + GameConstants.pipeGap / 2
        let botH = screenHeight - botTop + 100

        ZStack {
            if topH > 0 {
                VStack(spacing: 0) {
                    Spacer()
                    ZStack {
                        Ellipse().fill(leafColor)
                            .frame(width: GameConstants.pipeWidth + 20, height: 24)
                        ForEach([-14, -5, 5, 14], id: \.self) { x in
                            Ellipse().fill(leafHighlight)
                                .frame(width: 14, height: 10)
                                .offset(x: CGFloat(x), y: -7)
                        }
                    }
                    ZStack {
                        Rectangle().fill(trunkGrad)
                            .frame(width: GameConstants.pipeWidth, height: max(topH - 24, 0))
                        VStack(spacing: 20) {
                            ForEach(0..<max(1, Int(max(topH - 24, 0) / 20)), id: \.self) { _ in
                                Rectangle()
                                    .fill(Color(red: 0.30, green: 0.16, blue: 0.05).opacity(0.35))
                                    .frame(width: GameConstants.pipeWidth, height: 2.5)
                            }
                        }.frame(height: max(topH - 24, 0))
                    }
                }
                .frame(height: topH)
                .position(x: GameConstants.pipeWidth / 2, y: topH / 2)
            }

            if botH > 0 {
                VStack(spacing: 0) {
                    ZStack {
                        Rectangle().fill(trunkGrad)
                            .frame(width: GameConstants.pipeWidth, height: max(botH - 24, 0))
                        VStack(spacing: 20) {
                            ForEach(0..<max(1, Int(max(botH - 24, 0) / 20)), id: \.self) { _ in
                                Rectangle()
                                    .fill(Color(red: 0.30, green: 0.16, blue: 0.05).opacity(0.35))
                                    .frame(width: GameConstants.pipeWidth, height: 2.5)
                            }
                        }.frame(height: max(botH - 24, 0))
                    }
                    ZStack {
                        Ellipse().fill(leafColor)
                            .frame(width: GameConstants.pipeWidth + 20, height: 24)
                        ForEach([-14, -5, 5, 14], id: \.self) { x in
                            Ellipse().fill(leafHighlight)
                                .frame(width: 14, height: 10)
                                .offset(x: CGFloat(x), y: 7)
                        }
                    }
                    Spacer()
                }
                .frame(height: botH)
                .position(x: GameConstants.pipeWidth / 2, y: botTop + botH / 2)
            }
        }
        .frame(width: GameConstants.pipeWidth, height: screenHeight)
        .position(x: pipe.x + GameConstants.pipeWidth / 2, y: screenHeight / 2)
    }
}

// MARK: - Realistic Cloud
struct RealisticCloud: View {
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Base large puff
            Ellipse()
                .fill(Color.white.opacity(0.92))
                .frame(width: 90, height: 50)
                .offset(y: 10)

            // Left puff
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 54, height: 54)
                .offset(x: -28, y: 0)

            // Center big puff
            Circle()
                .fill(Color.white)
                .frame(width: 68, height: 68)
                .offset(x: 0, y: -8)

            // Right puff
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 50, height: 50)
                .offset(x: 28, y: 2)

            // Top left small puff
            Circle()
                .fill(Color.white.opacity(0.88))
                .frame(width: 36, height: 36)
                .offset(x: -14, y: -18)

            // Top right small puff
            Circle()
                .fill(Color.white.opacity(0.88))
                .frame(width: 32, height: 32)
                .offset(x: 16, y: -16)

            // Soft shadow bottom
            Ellipse()
                .fill(Color(red: 0.82, green: 0.88, blue: 0.95).opacity(0.45))
                .frame(width: 80, height: 18)
                .offset(y: 22)
                .blur(radius: 4)
        }
        .scaleEffect(scale)
        .frame(width: 110 * scale, height: 80 * scale)
    }
}

// MARK: - Nature Background
struct NatureBackgroundView: View {
    let cloudOffset: CGFloat
    let screenWidth: CGFloat

    var body: some View {
        ZStack {
            // Sky gradient
            LinearGradient(
                colors: [Color(red: 0.35, green: 0.68, blue: 0.96),
                         Color(red: 0.55, green: 0.82, blue: 0.98),
                         Color(red: 0.76, green: 0.92, blue: 0.99)],
                startPoint: .top, endPoint: .bottom
            )

            // Scrolling realistic clouds — two sets for seamless loop
            HStack(spacing: 0) {
                CloudLayer(width: screenWidth)
                CloudLayer(width: screenWidth)
            }
            .offset(x: cloudOffset)

            // Distant hills layer 1 (furthest, lightest)
            VStack {
                Spacer()
                ZStack {
                    Ellipse()
                        .fill(Color(red: 0.52, green: 0.76, blue: 0.44).opacity(0.40))
                        .frame(width: 380, height: 150)
                        .offset(x: -60, y: 60)
                    Ellipse()
                        .fill(Color(red: 0.52, green: 0.76, blue: 0.44).opacity(0.40))
                        .frame(width: 320, height: 130)
                        .offset(x: 100, y: 70)
                }
                .frame(height: 150).clipped()
            }

            // Distant hills layer 2 (closer, richer)
            VStack {
                Spacer()
                ZStack {
                    Ellipse()
                        .fill(Color(red: 0.38, green: 0.64, blue: 0.28).opacity(0.65))
                        .frame(width: 300, height: 120)
                        .offset(x: -80, y: 50)
                    Ellipse()
                        .fill(Color(red: 0.38, green: 0.64, blue: 0.28).opacity(0.65))
                        .frame(width: 260, height: 110)
                        .offset(x: 60, y: 55)
                    Ellipse()
                        .fill(Color(red: 0.38, green: 0.64, blue: 0.28).opacity(0.65))
                        .frame(width: 200, height: 100)
                        .offset(x: -170, y: 58)
                }
                .frame(height: 120).clipped()
            }

            // Full-width forest tree line behind ground
            VStack(spacing: 0) {
                Spacer()
                ForestTreeLine()
                    .frame(maxWidth: .infinity, maxHeight: 110)
                    .padding(.bottom, 80)
            }
        }
    }
}

// MARK: - Cloud Layer (one full screen width of clouds)
struct CloudLayer: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: width, height: 280)
            RealisticCloud(scale: 1.0).position(x: width * 0.10, y: 110)
            RealisticCloud(scale: 0.65).position(x: width * 0.32, y: 82)
            RealisticCloud(scale: 1.20).position(x: width * 0.60, y: 125)
            RealisticCloud(scale: 0.80).position(x: width * 0.84, y: 95)
        }
        .frame(width: width, height: 280)
        .clipped()
    }
}

// MARK: - Full width forest tree line
struct ForestTreeLine: View {
    let heights: [CGFloat] = [72, 88, 60, 82, 70, 94, 65, 78, 85, 68, 90, 75, 62, 86, 73, 80, 66, 92, 58, 76, 84, 69]
    let count = 22

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    VStack(spacing: 0) {
                        Spacer()
                        SingleTree(height: heights[i % heights.count], isDark: i % 3 == 0)
                    }
                    .frame(width: geo.size.width / CGFloat(count), height: geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
    }
}

struct SingleTree: View {
    let height: CGFloat
    let isDark: Bool

    var treeColor: Color {
        isDark
            ? Color(red: 0.14, green: 0.42, blue: 0.16)
            : Color(red: 0.20, green: 0.55, blue: 0.22)
    }
    var treeMid: Color {
        isDark
            ? Color(red: 0.18, green: 0.50, blue: 0.20)
            : Color(red: 0.26, green: 0.64, blue: 0.28)
    }

    var body: some View {
        VStack(spacing: -4) {
            // Top triangle
            TriangleShape()
                .fill(treeMid)
                .frame(width: height * 0.38, height: height * 0.42)
            // Mid triangle
            TriangleShape()
                .fill(treeColor)
                .frame(width: height * 0.50, height: height * 0.38)
            // Bottom triangle
            TriangleShape()
                .fill(treeColor.opacity(0.85))
                .frame(width: height * 0.60, height: height * 0.30)
            // Trunk
            Rectangle()
                .fill(Color(red: 0.35, green: 0.22, blue: 0.08).opacity(0.70))
                .frame(width: 6, height: height * 0.18)
        }
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Grass Ground
struct GrassGroundView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Grass bumps
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(0..<30, id: \.self) { _ in
                        Ellipse()
                            .fill(Color(red: 0.32, green: 0.72, blue: 0.22))
                            .frame(width: geo.size.width / 30, height: 15)
                    }
                }
                .frame(width: geo.size.width)
            }
            .frame(height: 15)
            .offset(y: 5)
            // Dirt strip
            Rectangle()
                .fill(Color(red: 0.70, green: 0.50, blue: 0.25))
                .frame(height: 13)
            // Ground fill
            Rectangle()
                .fill(Color(red: 0.44, green: 0.28, blue: 0.10))
                .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Score Banner (always visible top center)
struct ScoreBannerView: View {
    let score: Int
    let highScore: Int

    var body: some View {
        HStack(spacing: 20) {
            // Current score
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, Color(red: 0.95, green: 0.92, blue: 0.70)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 1, y: 2)
                Text("SCORE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(2)
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 1.5, height: 44)

            // High score
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Text("🏆").font(.system(size: 16))
                    Text("\(highScore)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                }
                Text("BEST")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(2)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
        )
    }
}

// MARK: - Main Game View
struct ContentView: View {
    @StateObject private var vm = GameViewModel()
    @State private var hasSetup = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                NatureBackgroundView(cloudOffset: vm.cloudOffset, screenWidth: w)

                ForEach(vm.pipes) { pipe in
                    NaturePipeView(pipe: pipe, screenHeight: h)
                }

                VStack {
                    Spacer()
                    GrassGroundView().frame(height: 90)
                }

                OSOView(rotation: vm.osoRotation)
                    .position(x: w * 0.28, y: vm.osoY)

                // Permanent score banner top center
                VStack {
                    ScoreBannerView(score: vm.score, highScore: vm.highScore)
                        .padding(.top, 56)
                    Spacer()
                }

                // +1 popup
                if vm.gameState == .playing && vm.showScorePopup {
                    Text("+1 🐾")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .position(x: w * 0.28 + 58, y: vm.osoY - 55)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 1.3).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }

                if vm.gameState == .waiting {
                    WaitingOverlay(highScore: vm.highScore)
                        .position(x: w / 2, y: h / 2)
                }
                if vm.gameState == .gameOver {
                    GameOverOverlay(score: vm.score, highScore: vm.highScore)
                        .position(x: w / 2, y: h / 2)
                }
            }
            .ignoresSafeArea()
            .onTapGesture { vm.tap() }
            .onAppear {
                if !hasSetup {
                    vm.setup(width: w, height: h)
                    hasSetup = true
                }
            }
        }
    }
}

// MARK: - Waiting Overlay
struct WaitingOverlay: View {
    let highScore: Int
    @State private var bounce = false
    @State private var floatY: CGFloat = 0

    var body: some View {
        VStack(spacing: 14) {
            Text("Happy OSO 🌿")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Color(red: 0.98, green: 0.95, blue: 0.70), .white],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: Color(red: 0.15, green: 0.45, blue: 0.10).opacity(0.9), radius: 5, x: 2, y: 3)

            Text("Amy & Oso's Adventure!")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))

            if highScore > 0 {
                HStack(spacing: 6) {
                    Text("🏆")
                    Text("Best: \(highScore)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                }
            }

            Spacer().frame(height: 6)

            Text("🌸 Tap to flap! 🌸")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 1.0, green: 0.95, blue: 0.50))
                .shadow(color: .black.opacity(0.4), radius: 2)
                .scaleEffect(bounce ? 1.12 : 0.94)
                .animation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true), value: bounce)
                .onAppear { bounce = true }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 0.14, green: 0.44, blue: 0.11).opacity(1.0))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.25), lineWidth: 1.5))
        )
        .shadow(color: .black.opacity(0.3), radius: 12)
        .padding(.horizontal, 36)
        .offset(y: floatY)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { floatY = -8 }
        }
    }
}

// MARK: - Game Over Overlay
struct GameOverOverlay: View {
    let score: Int
    let highScore: Int
    @State private var appeared = false
    @State private var starScale: CGFloat = 0.5

    var isNewBest: Bool { score >= highScore && score > 0 }

    var body: some View {
        VStack(spacing: 16) {
            Text("Oof! 🐾")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 1.0, green: 0.40, blue: 0.35))

            Text("Score: \(score)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(.white)

            if isNewBest {
                Text("🌟 New Best! 🌟")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                    .scaleEffect(starScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { starScale = 1.0 }
                    }
            } else {
                Text("Best: \(highScore)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer().frame(height: 4)

            Text("Tap to try again!")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 26).padding(.vertical, 13)
                .background(
                    Capsule().fill(Color(red: 0.28, green: 0.68, blue: 0.28))
                        .shadow(color: .black.opacity(0.2), radius: 4)
                )
        }
        .padding(.horizontal, 32).padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 0.10, green: 0.32, blue: 0.08).opacity(0.82))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
        )
        .shadow(color: .black.opacity(0.35), radius: 14)
        .padding(.horizontal, 36)
        .scaleEffect(appeared ? 1.0 : 0.4)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.60)) { appeared = true }
        }
    }
}

// MARK: - App Entry
@main
struct HappyOSOApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().preferredColorScheme(.light)
        }
    }
}
