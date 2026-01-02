import SwiftUI

struct UsageView: View {
    let account: ClaudeAccount
    let isFetching: Bool
    var onPing: (() -> Void)?
    
    init(account: ClaudeAccount, isFetching: Bool, onPing: (() -> Void)? = nil) {
        self.account = account
        self.isFetching = isFetching
        self.onPing = onPing
    }
    
    @State private var isHovering = false
    @State private var showStartText = false
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    private let gaugeLineThickness: CGFloat = 5
    
    var tierColor: Color {
        let tier = account.usageData?.tier.lowercased() ?? ""
        if tier.contains("max") { return .yellow }
        if tier.contains("team") { return .purple }
        return .blue // Default/Pro
    }
    
    // Dynamic color based on usage percentage: green -> yellow -> red (for session)
    func sessionColor(for percentage: Double) -> Color {
        if percentage < 0.5 {
            return .green
        } else if percentage < 0.75 {
            return .yellow
        } else {
            return .red
        }
    }
    
    // Session gauge gradient
    func sessionGradient(for percentage: Double) -> Gradient {
        if percentage < 0.5 {
            return Gradient(colors: [.green, .yellow])
        } else if percentage < 0.75 {
            return Gradient(colors: [.yellow, .orange])
        } else {
            return Gradient(colors: [.orange, .red])
        }
    }
    
    func percentageText(for percentage: Double) -> String {
        let value = Int((percentage * 100).rounded())
        return "\(value)%"
    }
    
    func weeklyGradient(for percentage: Double) -> Gradient {
        if percentage < 0.5 {
            return Gradient(colors: [.mint, .teal])
        } else if percentage < 0.75 {
            return Gradient(colors: [.teal, .indigo])
        } else {
            return Gradient(colors: [.indigo, .pink])
        }
    }
    
    var body: some View {
        Group {
            if let usage = account.usageData {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 20) {
                        VStack(alignment: .center, spacing: 4) {
                            Text("Weekly")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 4)
                            
                            Gauge(value: usage.weeklyPercentage) {
                                EmptyView()
                            } currentValueLabel: {
                                Text(percentageText(for: usage.weeklyPercentage))
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                            .gaugeStyle(.accessoryCircular)
                            .tint(AngularGradient(gradient: weeklyGradient(for: usage.weeklyPercentage), center: .center))
                            .frame(width: 42, height: 42)
                            
                            Text(usage.weeklyReset)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 6)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.trailing, 2)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(account.name)
                                    .font(.system(.headline, design: .rounded))
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                if isFetching {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                }
                                
                                Text(usage.tier.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.system(.caption2, design: .rounded).bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(tierColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            
                            HStack {
                                Text("Session Usage (5 hr rolling window)")
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                if usage.sessionReset == "Ready" {
                                    Button(action: { onPing?() }) {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.green)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Text(percentageText(for: usage.sessionPercentage))
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(usage.sessionReset == "Ready" ? "Ready to start new session" : "Resets in: \(usage.sessionReset)")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            Gauge(value: usage.sessionPercentage) {
                                EmptyView()
                            }
                            .gaugeStyle(.accessoryLinear)
                            .tint(sessionGradient(for: usage.sessionPercentage))
                            .controlSize(.small)
                            .scaleEffect(y: 1.45)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                LoadingCardView()
            }
        }
        .padding(16)
        .background(Material.regular)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1) // Subtle border for definition
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2) // Deeper shadow for pop
    }
}

struct LoadingCardView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .center, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 36, height: 10)
                
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 42, height: 42)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 48, height: 10)
            }
            .fixedSize(horizontal: true, vertical: false)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 140, height: 16)
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 12, height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 48, height: 14)
                }
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 180, height: 12)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 120, height: 10)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 6)
            }
        }
        .opacity(isAnimating ? 0.5 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
