import SwiftUI

/// Saved on this device. Chat views read them with `@AppStorage`, so a change
/// shows the next time a chat draws.
enum ChatLayoutPreferences {
    static let avatarSizeKey = "bighelp.chat.avatar-size"
    static let showsAgentNameKey = "bighelp.chat.shows-agent-name"
    static let textSizeKey = "bighelp.chat.text-size"
    static let densityKey = "bighelp.chat.density"
    /// Settings › Appearance › Agent messages (`ChatAgentMessageStyle`).
    static let agentMessageStyleKey = "bighelp.appearance.agent-messages"
    /// With a hardware keyboard, Return sends (true) or adds a line (false).
    static let returnSendsKey = "bighelp.chat.return-sends"
    /// Settings › Chat › Chat title: the chat's title under the agent's name. Off by default.
    static let showsSessionTitleKey = "bighelp.chat.shows-session-title"
    static let showsSessionTitleByDefault = false
    /// Settings › Chat › Project names: each chat's project on a line of its own in
    /// Chats. On by default.
    static let showsChatProjectKey = "bighelp.chat-list.shows-project"
    static let showsChatProjectByDefault = true

    /// The Pro Max and Plus phones are at least this tall, in points.
    static let tallPhoneHeight: CGFloat = 900
}

/// The agent's avatar at the top of a chat.
enum ChatAvatarSize: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case small
    case medium
    case large

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: String(localized: "Auto")
        case .small: String(localized: "Small")
        case .medium: String(localized: "Medium")
        case .large: String(localized: "Large")
        }
    }

    /// Auto keeps the large avatar on the tallest phones and uses Medium on the
    /// rest, where the header and bottom bar otherwise crowd the messages.
    /// At the chosen button size (Settings › Appearance).
    func points(screenHeight: CGFloat) -> CGFloat {
        let points: CGFloat = switch self {
        case .small: 44
        case .medium: 60
        case .large: 76
        case .automatic: screenHeight >= ChatLayoutPreferences.tallPhoneHeight ? 76 : 60
        }
        return BighelpTokens.scaled(points)
    }
}

/// Message text size, on top of the iPhone's own text size setting.
enum ChatTextSize: Int, CaseIterable, Identifiable, Sendable {
    case smaller = -2
    case small = -1
    case standard = 0
    case large = 1
    case larger = 2

    /// Messages size on top of the app's text size (Appearance); out of the box, the
    /// same size (one step under it before). A size someone picked is saved and stays.
    static let defaultSize: ChatTextSize = .standard

    var id: Self { self }

    var title: String {
        switch self {
        case .smaller: String(localized: "Smaller")
        case .small: String(localized: "Small")
        case .standard: String(localized: "Medium")
        case .large: String(localized: "Large")
        case .larger: String(localized: "Larger")
        }
    }

    var scale: CGFloat {
        switch self {
        case .smaller: 0.85
        case .small: 0.93
        case .standard: 1
        case .large: 1.1
        case .larger: 1.22
        }
    }
}

/// Room around and between messages.
enum ChatDensity: String, CaseIterable, Identifiable, Sendable {
    case comfortable
    case compact

    var id: Self { self }

    var title: String {
        switch self {
        case .comfortable: String(localized: "Comfortable")
        case .compact: String(localized: "Compact")
        }
    }

    /// Space below a message when the next one is from someone else.
    var messageSpacing: CGFloat { self == .compact ? 10 : BighelpTokens.space16 }
    var bubbleHorizontalPadding: CGFloat {
        self == .compact ? 11 : BighelpV3MessagePresentation.horizontalContentPadding
    }
    var bubbleVerticalPadding: CGFloat { self == .compact ? 7 : 10 }
}

/// Agent replies in a bubble (the default), or on the page at the chat lane's full width with no
/// fill, border or bubble padding. The person's own messages keep their bubble either way.
enum ChatAgentMessageStyle: String, CaseIterable, Identifiable, Sendable {
    case bubble
    case page

    var id: Self { self }

    var title: String {
        switch self {
        case .bubble: String(localized: "Bubble")
        case .page: String(localized: "On the page")
        }
    }
}

/// Settings › Appearance › Chat layout.
struct ChatLayoutSettingsView: View {
    @AppStorage(ChatLayoutPreferences.avatarSizeKey) private var avatarSize: ChatAvatarSize = .automatic
    @AppStorage(ChatLayoutPreferences.showsAgentNameKey) private var showsAgentName = true
    @AppStorage(ChatLayoutPreferences.textSizeKey) private var textSize: ChatTextSize = .defaultSize
    @AppStorage(ChatLayoutPreferences.densityKey) private var density: ChatDensity = .comfortable
    @AppStorage(LinkPreviewPreferences.enabledKey) private var showsLinkPreviews = true
    @BighelpThemeReader private var theme

    var body: some View {
        Form {
            Section {
                ChatLayoutPreview(avatarSize: avatarSize.points(screenHeight: previewScreenHeight),
                                  showsAgentName: showsAgentName, textSize: textSize, density: density)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }
            .listRowBackground(theme.canvas)

            Section {
                Picker("Avatar size", selection: $avatarSize) {
                    ForEach(ChatAvatarSize.allCases) { Text($0.title).tag($0) }
                }
                .bighelpSegmentedPicker()
                .frame(minHeight: BighelpTokens.hitTarget)
                .accessibilityIdentifier("chat-layout.avatar-size")
                Toggle("Show bot name", isOn: $showsAgentName)
                    .accessibilityIdentifier("chat-layout.shows-name")
            } header: {
                Text("Chat header")
            } footer: {
                Text(Self.headerNote)
            }
            .listRowBackground(theme.surface)

            Section {
                HStack(spacing: BighelpTokens.space12) {
                    Image(systemName: "textformat.size.smaller")
                        .accessibilityHidden(true)
                    Slider(value: textSizeValue, in: -2...2, step: 1)
                        .accessibilityLabel("Text size")
                        .accessibilityValue(textSize.title)
                        .accessibilityIdentifier("chat-layout.text-size")
                    Image(systemName: "textformat.size.larger")
                        .accessibilityHidden(true)
                }
                .frame(minHeight: BighelpTokens.hitTarget)
                Picker("Spacing", selection: $density) {
                    ForEach(ChatDensity.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("chat-layout.density")
                Toggle("Link previews", isOn: $showsLinkPreviews)
                    .accessibilityIdentifier("chat-layout.link-previews")
            } header: {
                Text("Messages")
            } footer: {
                Text(String(localized: "Text size: \(textSize.title). \(Self.messagesNote)"))
            }
            .listRowBackground(theme.surface)

            Section {
                Button("Reset to defaults") {
                    avatarSize = .automatic
                    showsAgentName = true
                    textSize = .defaultSize
                    density = .comfortable
                    showsLinkPreviews = true
                }
                .accessibilityIdentifier("chat-layout.reset")
            }
            .listRowBackground(theme.surface)
        }
        .bighelpFormSurface()
        .environment(\.defaultMinListRowHeight, BighelpTokens.hitTarget)
        .scrollContentBackground(.hidden)
        .background(theme.canvas.ignoresSafeArea())
        .foregroundStyle(theme.primaryText)
        .tint(theme.action)
        .navigationTitle("Chat layout")
        .navigationBarTitleDisplayMode(.inline)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
        } action: { previewScreenHeight = $0 }
    }

    @State private var previewScreenHeight: CGFloat = 0

    private static var headerNote: String {
        #if targetEnvironment(macCatalyst)
        String(localized: """
            Auto uses the large avatar in tall windows and Medium in shorter ones. With the name hidden, click the \
            avatar for the bot's profile, or click and hold it to switch bots.
            """)
        #else
        String(localized: """
            Auto keeps the large avatar on the biggest iPhones and uses Medium on the rest. With the name hidden, \
            tap the avatar for the bot's profile, or touch and hold it to switch bots.
            """)
        #endif
    }

    private static var messagesNote: String {
        #if targetEnvironment(macCatalyst)
        // Appearance has the app-wide text size; this one is for messages only.
        String(localized: """
            It sizes message text, on top of the text size in Appearance. Link previews show a web link's picture, \
            title and summary in chats and the Feed. To make one, your Mac opens that page, without cookies.
            """)
        #else
        String(localized: """
            It sizes message text, on top of the text size in Appearance and your iPhone's own text size. Link \
            previews show a web link's picture, title and summary in chats and the Feed. To make one, your iPhone \
            opens that page, without cookies.
            """)
        #endif
    }

    private var textSizeValue: Binding<Double> {
        Binding(get: { Double(textSize.rawValue) },
                set: { textSize = ChatTextSize(rawValue: Int($0.rounded())) ?? .defaultSize })
    }
}

/// A small, static picture of the chat with the chosen layout.
private struct ChatLayoutPreview: View {
    let avatarSize: CGFloat
    let showsAgentName: Bool
    let textSize: ChatTextSize
    let density: ChatDensity
    @BighelpThemeReader private var theme
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 17

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Circle()
                    .fill(theme.action)
                    .frame(width: avatarSize, height: avatarSize)
                if showsAgentName {
                    Text("Your bot")
                        .font(.bighelp(.subheadline).weight(.semibold))
                        .padding(.horizontal, BighelpTokens.space16)
                        .padding(.vertical, 6)
                        .background(theme.surface, in: Capsule())
                }
            }
            .padding(.bottom, BighelpTokens.space12)
            .animation(.snappy, value: avatarSize)
            .animation(.snappy, value: showsAgentName)

            bubble(String(localized: "Can you look over my notes before the meeting?"), outgoing: true)
                .padding(.bottom, density.messageSpacing)
            bubble(String(localized: "Sure. I added two questions and fixed the dates."), outgoing: false)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of a chat with these settings")
        .accessibilityIdentifier("chat-layout.preview")
    }

    /// Message text before the chat's own size: the Mac's text styles are fixed, so
    /// there messages start from the size in Appearance, as they do in a chat.
    private var bodyPointSize: CGFloat {
        #if targetEnvironment(macCatalyst)
        Font.TextStyle.body.macPointSize
        #else
        bodySize
        #endif
    }

    private func bubble(_ text: String, outgoing: Bool) -> some View {
        HStack {
            if outgoing { Spacer(minLength: 40) }
            Text(text)
                .font(.system(size: (bodyPointSize * textSize.scale).rounded()))
                .foregroundStyle(outgoing ? theme.outgoingMessageForeground : theme.primaryText)
                .padding(.horizontal, density.bubbleHorizontalPadding)
                .padding(.vertical, density.bubbleVerticalPadding)
                .background(outgoing ? theme.outgoingMessageBackground : theme.incomingMessageBackground,
                            in: RoundedRectangle(cornerRadius: BighelpV3MessagePresentation.bubbleRadius,
                                                 style: .continuous))
            if !outgoing { Spacer(minLength: 40) }
        }
    }
}

/// Settings › Chat › Chat rows: which tags each chat in the list carries under its title, in what
/// order, and whether they sit beside the preview or on a line of their own. The picture at the top
/// is drawn from the same `SessionRowLayout` the rows themselves read, so it can't drift from them.
struct SessionRowSettingsView: View {
    @AppStorage(SessionRowLayout.key) private var savedLayout = ""
    @State private var isResetConfirmationPresented = false

    private var layout: SessionRowLayout { SessionRowLayout(saved: savedLayout) }

    /// One change, saved once. Anything unreadable falls back to the standard row, never to a blank.
    private func update(_ change: (inout SessionRowLayout) -> Void) {
        var next = layout
        change(&next)
        savedLayout = next.saved ?? ""
    }

    var body: some View {
        List {
            Section {
                SessionRowSettingsPreview(layout: layout)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            } footer: {
                Text("A sample row. Every chat in the list is drawn the same way.")
            }
            .listRowBackground(theme.canvas)

            Section {
                ForEach(layout.chips) { detail in
                    HStack(spacing: BighelpTokens.space12) {
                        circleButton("minus.circle.fill", tint: theme.danger,
                                     label: String(localized: "Hide \(detail.title)"),
                                     id: "chat-rows.hide.\(detail.rawValue)") {
                            withAnimation { update { $0.hide(detail) } }
                        }
                        tagLabel(detail)
                    }
                    // Keeps the hide button's own identifier reachable.
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("chat-rows.shown.\(detail.rawValue)")
                }
                .onMove { source, destination in
                    update { $0.moveChips(from: source, to: destination) }
                }
            } header: {
                Text("Shown on a row")
            } footer: {
                Text("Drag to change the order. A row shows up to \(SessionRowLayout.maximumChips) tags, so the preview keeps its room.")
            }
            .listRowBackground(theme.surface)

            Section {
                ForEach(SessionRowDetail.allCases.filter { !layout.isShown($0) }) { detail in
                    HStack(spacing: BighelpTokens.space12) {
                        circleButton("plus.circle.fill",
                                     tint: layout.canShowMore ? theme.success : theme.tertiaryText,
                                     label: String(localized: "Show \(detail.title)"),
                                     id: "chat-rows.add.\(detail.rawValue)") {
                            withAnimation { update { $0.show(detail) } }
                        }
                        .disabled(!layout.canShowMore)
                        tagLabel(detail)
                    }
                    .moveDisabled(true)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("chat-rows.more.\(detail.rawValue)")
                }
            } header: {
                Text("More to show")
            } footer: {
                Text(layout.canShowMore
                     ? "A tag draws only when the chat has something for it."
                     : "A row is full. Hide one to add another.")
            }
            .listRowBackground(theme.surface)

            Section {
                Picker("Tags sit", selection: placement) {
                    ForEach(SessionRowChipPlacement.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("chat-rows.placement")
                Toggle("Preview text", isOn: showsPreview)
                    .accessibilityIdentifier("chat-rows.preview")
                Toggle("Time", isOn: showsTime)
                    .accessibilityIdentifier("chat-rows.time")
            } header: {
                Text("Under the title")
            } footer: {
                Text("Beside the preview keeps Messages' single line. On their own line keeps the whole preview at every text size.")
            }
            .listRowBackground(theme.surface)

            Section {
                Button("Reset to Default Row", role: .destructive) {
                    isResetConfirmationPresented = true
                }
                .disabled(layout == .standard)
                .accessibilityIdentifier("chat-rows.reset")
            }
            .listRowBackground(theme.surface)
        }
        .alert("Reset to the default row?", isPresented: $isResetConfirmationPresented) {
            Button("Reset", role: .destructive) {
                withAnimation { savedLayout = SessionRowLayout.standard.saved ?? "" }
            }
            .accessibilityIdentifier("chat-rows.reset.confirm")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A chat shows where it started beside its preview, with its time. Project names in Chat keeps its own line.")
        }
        // Handles to drag. Showing and hiding are their own buttons.
        .environment(\.editMode, .constant(.active))
        .environment(\.defaultMinListRowHeight, BighelpTokens.hitTarget)
        .scrollContentBackground(.hidden)
        .background(BighelpThemeCanvas(theme: theme).ignoresSafeArea())
        .navigationTitle("Chat rows")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("chat-rows")
    }

    private var placement: Binding<SessionRowChipPlacement> {
        Binding(get: { layout.placement }, set: { place in update { $0.placement = place } })
    }

    private var showsPreview: Binding<Bool> {
        Binding(get: { layout.showsPreview }, set: { on in update { $0.showsPreview = on } })
    }

    private var showsTime: Binding<Bool> {
        Binding(get: { layout.showsTime }, set: { on in update { $0.showsTime = on } })
    }

    private func circleButton(_ symbol: String, tint: Color, label: String, id: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.bighelp(.title3))
                .foregroundStyle(tint)
                .frame(minWidth: BighelpTokens.hitTarget, minHeight: BighelpTokens.hitTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func tagLabel(_ detail: SessionRowDetail) -> some View {
        HStack(spacing: BighelpTokens.space12) {
            BighelpIconTile(systemName: detail.symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.title)
                    .bighelpFont(.body)
                    .foregroundStyle(theme.primaryText)
                Text(detail.detail)
                    .font(.bighelp(.footnote))
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: BighelpTokens.hitTarget)
        .accessibilityElement(children: .combine)
    }

    @BighelpThemeReader private var theme
}

/// A small, static picture of one chat row with the chosen tags. Made-up words only.
private struct SessionRowSettingsPreview: View {
    let layout: SessionRowLayout
    @BighelpThemeReader private var theme
    @ScaledMetric(relativeTo: .footnote) private var tagSize: CGFloat = 11

    var body: some View {
        HStack(spacing: BighelpTokens.space12) {
            Circle()
                .fill(theme.incomingMessageBackground)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: BighelpTokens.space8) {
                    Text("Planning the weekend")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: BighelpTokens.space4)
                    if layout.showsTime {
                        Text("9:41 AM")
                            .font(.system(size: 13))
                            .monospacedDigit()
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                }
                if layout.placement == .abovePreview, !layout.chips.isEmpty {
                    HStack(spacing: 4) { tags }
                }
                HStack(spacing: 6) {
                    if layout.placement == .besidePreview { tags }
                    if layout.showsPreview {
                        Text("Sure. I added two questions and fixed the dates.")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: BighelpTokens.hitTarget, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of a chat row with these tags")
        .accessibilityIdentifier("chat-rows.preview-row")
    }

    private var tags: some View {
        ForEach(layout.chips) { detail in
            SessionRowChip(text: Self.sampleText(detail), size: tagSize)
        }
    }

    /// What each tag says on a made-up row.
    private static func sampleText(_ detail: SessionRowDetail) -> String {
        switch detail {
        case .origin: String(localized: "Telegram")
        case .project: String(localized: "Kitchen")
        case .scheduled: String(localized: "Scheduled")
        case .group: String(localized: "Group")
        case .agents: String(localized: "Tandy, Nova")
        }
    }
}
