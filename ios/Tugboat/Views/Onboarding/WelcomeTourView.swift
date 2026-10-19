import SwiftUI

/// The swipeable intro shown once before the sign-in screen (see `WelcomeTourPolicy`) and replayable from
/// Settings → About. Every page is the app's own UI drawn with sample data, not a screenshot, so it follows the
/// theme, dark mode and text size and doesn't go stale when the app changes.
///
/// (Not `OnboardingView`, which is the "create your household" step after sign-up.)
struct WelcomeTourView: View {
    /// A replay from Settings leaves out the last page, which leads into signing in.
    var replay = false
    let onFinish: () -> Void

    @State private var selection = 0

    private var pages: [WelcomeTourPage] { WelcomeTourPage.pages(replay: replay) }
    private var isLast: Bool { selection >= pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                // Always there, on every page.
                Button(replay ? "Close" : "Skip") { onFinish() }
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 8)
                    .minimumTapTarget()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            TabView(selection: $selection) {
                ForEach(pages) { page in
                    WelcomeTourPageView(page: page)
                        .tag(page.rawValue)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.vertical, 14)

            Button {
                if isLast {
                    onFinish()
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) { selection += 1 }
                }
            } label: {
                Text(isLast ? (replay ? "Done" : "Get Started") : "Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HubTheme.canvas)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(pages) { page in
                Circle()
                    .fill(page.rawValue == selection ? HubTheme.accentText : HubTheme.muted.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(selection + 1) of \(pages.count)")
    }
}

/// One page: the picture, then the title and the sentence under it. It scrolls only when the text size is
/// large enough that it must, and is centred otherwise (a wide iPad shouldn't leave it stuck at the top).
private struct WelcomeTourPageView: View {
    let page: WelcomeTourPage

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 0)
                    if page == .today {
                        VStack(spacing: 2) {
                            Text("Tugboat")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                            Text("Moving you in the right direction")
                                .font(.subheadline)
                                .foregroundStyle(HubTheme.muted)
                                .multilineTextAlignment(.center)
                        }
                    }
                    art
                        // The picture is an illustration: it keeps its size so it stays a picture, while the title
                        // and sentence under it grow with the reader's text size.
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        .frame(maxWidth: 440)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(page.pictureDescription)
                    VStack(spacing: 10) {
                        Text(page.headline)
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .multilineTextAlignment(.center)
                            // Take the lines the words need, however narrow the screen or large the text.
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(page.detail)
                            .font(.body)
                            .foregroundStyle(HubTheme.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 440)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var art: some View {
        switch page {
        case .today: WelcomeTodayArt()
        case .together: WelcomeTogetherArt()
        case .lockScreen: WelcomeLockScreenArt()
        case .widgets: WelcomeWidgetsArt()
        case .start: WelcomeStartArt()
        }
    }
}
