import Foundation
import SwiftUI

/// One Messages-style inbox row: the agent avatar doubles as the live status, then a single
/// title line, the tags list rows are set to show (where a chat started, its project, ...), a
/// single plain-text preview line, and the chat's project on a line of its own when `showsProject`.
struct SessionRow: View {
    let session: SessionSummary
    let agents: AgentDirectoryStore
    /// Settings › Chat › Project names, unless the list groups by project, where
    /// the section header already says it. A line of its own keeps the preview whole at every
    /// text size. The project tag in `layout` replaces it, so a row never says it twice.
    var showsProject = false
    /// Settings › Appearance › Chat rows: which tags the row shows, in what order, and whether
    /// they sit beside the preview or on a line of their own.
    var layout: SessionRowLayout = .standard

    static let avatarSize: CGFloat = 52
    /// Separators start where the text column starts, like Messages.
    static let textLeading: CGFloat = avatarSize + BighelpTokens.space12

    @ScaledMetric(relativeTo: .callout) private var titleSize: CGFloat = 16
    @ScaledMetric(relativeTo: .footnote) private var timeSize: CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var previewSize: CGFloat = 14

    var body: some View {
        HStack(spacing: BighelpTokens.space12) {
            SessionIdentityView(session: session, agents: agents, size: Self.avatarSize, state: liveState)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: BighelpTokens.space8) {
                    Text(session.title)
                        .font(.system(size: titleSize, weight: session.isUnread ? .bold : .semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                    if session.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: timeSize * 0.8))
                            .foregroundStyle(theme.tertiaryText)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: BighelpTokens.space4)
                    Text(Self.compactTimestamp(session.updatedAt))
                        .font(.system(size: timeSize))
                        .monospacedDigit()
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                        .layoutPriority(1)
                    // The Bots view's dot, in the same place: after the time, clear of the live dot below.
                    if session.isUnread {
                        Circle()
                            .fill(theme.information)
                            .frame(width: 9, height: 9)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + timeSize * 0.32 }
                            .accessibilityHidden(true)
                    }
                }

                if layout.placement == .abovePreview, !chipTexts.isEmpty {
                    HStack(spacing: 4) {
                        chips
                    }
                }

                HStack(spacing: 6) {
                    if liveState != .idle {
                        Circle()
                            .fill(liveState.dotColor)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                    }
                    if layout.placement == .besidePreview {
                        chips
                    }
                    if session.hasDraft {
                        HStack(spacing: 2) {
                            Image(systemName: "pencil")
                            Text("Draft")
                        }
                        .font(.system(size: timeSize * 0.85, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                        .accessibilityHidden(true)
                    }
                    if layout.showsPreview {
                        Text(previewLine)
                            .font(.system(size: previewSize))
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                if let project = shownProject {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: timeSize * 0.9))
                        Text(project)
                            .font(.system(size: timeSize, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .foregroundStyle(theme.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: BighelpTokens.hitTarget, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("session.row.\(session.id)")
    }

    /// The tags this row shows, in the order Settings puts them, each with the text it carries
    /// for this chat. A tag with nothing to say draws nothing.
    private struct Chip: Identifiable {
        let detail: SessionRowDetail
        let text: String

        var id: SessionRowDetail { detail }
    }

    private var chipTexts: [Chip] {
        layout.chips.compactMap { detail in
            chipText(detail).map { Chip(detail: detail, text: $0) }
        }
    }

    @ViewBuilder private var chips: some View {
        ForEach(chipTexts) { chip in
            SessionRowChip(text: chip.text, size: timeSize * 0.85)
        }
    }

    private func chipText(_ detail: SessionRowDetail) -> String? {
        switch detail {
        case .origin:
            return SessionOrigin.label(session.origin)
        case .project:
            // The chat's project, the same name the project's section header uses.
            guard let name = session.workspaceName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return nil }
            return SessionRowLayout.bounded(name)
        case .scheduled:
            return session.isCronSession ? String(localized: "Scheduled") : nil
        case .group:
            return session.kind == .botMode ? String(localized: "Group") : nil
        case .agents:
            // A single agent is already on the row as its avatar.
            return session.agentIDs.count > 1 ? SessionRowLayout.bounded(agentNames.joined(separator: ", ")) : nil
        }
    }

    private var shownProject: String? {
        // The project tag says it in the row's own tags instead, so it never appears twice.
        guard showsProject, !layout.isShown(.project),
              let name = session.workspaceName, !name.isEmpty else { return nil }
        return name
    }

    /// Live state from the catalog's real activity flag; nothing is inferred.
    private var liveState: AgentLiveState { session.isActive ? .thinking : .idle }

    private var plainPreview: String { SessionPreviewText.plain(session.preview) }

    private var previewLine: String {
        if !plainPreview.isEmpty { return plainPreview }
        if liveState != .idle { return liveState.label }
        return agentNames.joined(separator: ", ")
    }

    /// Messages-style timestamp: time today, then "Yesterday", weekday, or a short date.
    nonisolated static func compactTimestamp(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        // Relative to `now`, not the device clock, so it holds across midnight and time zones.
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "Yesterday")
        }
        let startOfToday = calendar.startOfDay(for: now)
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday), date >= weekAgo, date < now {
            return date.formatted(.dateTime.weekday(.wide))
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(date: .numeric, time: .omitted)
    }

    private var profilesByID: [String: AgentProfile] {
        Dictionary(uniqueKeysWithValues: agents.profiles.map { ($0.id, $0) })
    }

    private var agentNames: [String] {
        session.agentIDs.map { profilesByID[$0]?.name ?? "Unavailable bot" }
    }

    private var accessibilityLabel: String {
        let kind = session.kind == .botMode ? "Group chat" : "Chat"
        let preview = plainPreview.isEmpty ? "No preview" : plainPreview
        let state = [
            session.isUnread ? "Unread" : nil,
            session.hasDraft ? "Draft" : nil,
            session.isActive ? "Active" : nil,
            session.isPinned ? "Pinned" : nil,
        ].compactMap { $0 }.joined(separator: ", ")
        let stateLabel = state.isEmpty ? "" : "\(state). "
        let origin = SessionOrigin.label(session.origin).map { " Started in \($0)." } ?? ""
        let projectShown = shownProject != nil || (layout.isShown(.project) && chipText(.project) != nil)
        let project = projectShown ? session.workspaceName.map { " In project \($0)." } ?? "" : ""
        let scheduled = layout.isShown(.scheduled) && session.isCronSession ? " Scheduled." : ""
        return "\(session.title). \(stateLabel)\(preview). \(agentNames.joined(separator: ", ")). \(kind).\(origin)\(project)\(scheduled) \(session.updatedAt.formatted(.relative(presentation: .named)))"
    }

    @BighelpThemeReader private var theme

}

/// Reduces a Markdown message preview to one line of plain text so list rows
/// never show raw `**`, `#`, or link syntax.
enum SessionPreviewText {
    nonisolated static func plain(_ raw: String) -> String {
        // Another agent's message or answer reads as theirs, never as Hermes' wrapper.
        if raw.hasPrefix("[IMPORTANT: Background process "), let delivery = AgentTalkDelivery.parse(raw) {
            let name = AgentTalkCall(targetID: delivery.targetID ?? "agent", message: nil, route: .message)
                .fallbackTargetName
            return delivery.reply.map { "\(name): " + markdownPlain($0) } ?? "\(name) didn't answer"
        }
        if raw.hasPrefix("Message from"), let incoming = AgentTalkIncomingMessage.parse(raw), incoming.body != raw {
            return "\(incoming.senderName): " + markdownPlain(incoming.body)
        }
        // A helper's report is for the model; a list preview may cut it short, so it doesn't count tasks.
        if raw.hasPrefix("[ASYNC DELEGATION ") {
            return raw.hasPrefix("[ASYNC DELEGATION TASK FAILED") ? "A helper failed" : "Helpers reported back"
        }
        return markdownPlain(raw)
    }

    private nonisolated static func markdownPlain(_ raw: String) -> String {
        // Previews render on one line; bound the parse work for long replies.
        let bounded = String(raw.prefix(600))
        var lines: [String] = []
        var insideFence = false
        for line in bounded.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                insideFence.toggle()
                continue
            }
            if insideFence {
                lines.append(trimmed)
                continue
            }
            // Block markers: headings, quotes, list bullets, task boxes, rules.
            let unblocked = trimmed.replacingOccurrences(
                of: #"^(?:#{1,6}\s+|>\s*|[-*+]\s+(?:\[[ xX]\]\s+)?|\d+[.)]\s+)+"#,
                with: "",
                options: .regularExpression
            )
            if unblocked.range(of: #"^(?:[-*_]\s*){3,}$"#, options: .regularExpression) != nil { continue }
            if !unblocked.isEmpty { lines.append(unblocked) }
        }
        let joined = lines.joined(separator: " ")
        let inline: String
        if let attributed = try? AttributedString(
            markdown: joined,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            inline = String(attributed.characters)
        } else {
            inline = joined
        }
        return inline
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// The identity for chat rows and pins. Single-agent chats show that agent's
/// avatar with its live state; group chats show an overlapping avatar stack.
struct SessionIdentityView: View {
    let session: SessionSummary
    let agents: AgentDirectoryStore
    let size: CGFloat
    var state: AgentLiveState = .idle

    var body: some View {
        Group {
            if identities.count == 1, let identity = identities.first {
                AvatarView(
                    stableID: identity.id,
                    displayName: identity.name,
                    imageURL: identity.imageURL,
                    size: size,
                    state: state
                )
            } else {
                AvatarStack(
                    avatars: identities.prefix(2).map {
                        AvatarStack.Avatar(stableID: $0.id, displayName: $0.name, imageURL: $0.imageURL)
                    },
                    size: size * 0.65,
                    outlineColor: theme.canvas
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.title)
    }

    private struct Identity: Identifiable {
        let id: String
        let name: String
        let imageURL: URL?
    }

    private var identities: [Identity] {
        let mapped = session.agentIDs.prefix(4).map { agentID -> Identity in
            guard let profile = agents.profiles.first(where: { $0.id == agentID }) else {
                return Identity(id: "unavailable-\(agentID)", name: "Unavailable bot", imageURL: nil)
            }
            return Identity(id: profile.id, name: profile.name, imageURL: agents.avatarURL(for: profile))
        }
        return mapped.isEmpty
            ? [Identity(id: "session-\(session.id)", name: session.title, imageURL: nil)]
            : mapped
    }

    @BighelpThemeReader private var theme
}

/// Shape-matched stand-in for `SessionRow` while the first page of chats loads.
struct SessionRowPlaceholder: View {
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: BighelpTokens.space12) {
            Circle()
                .fill(theme.incomingMessageBackground)
                .frame(width: SessionRow.avatarSize, height: SessionRow.avatarSize)
            VStack(alignment: .leading, spacing: BighelpTokens.space8) {
                HStack {
                    bar(width: index.isMultiple(of: 2) ? 140 : 100, height: 14)
                    Spacer(minLength: BighelpTokens.space8)
                    bar(width: 36, height: 10)
                }
                bar(width: index.isMultiple(of: 3) ? 160 : 220, height: 12)
            }
        }
        .padding(.vertical, BighelpTokens.space4)
        .opacity(isPulsing ? 0.45 : 1)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                .delay(Double(index) * 0.08),
            value: isPulsing
        )
        .onAppear { isPulsing = true }
    }

    private func bar(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(theme.incomingMessageBackground)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    @BighelpThemeReader private var theme
}

/// First-run Chats screen: one clear action, then three plain steps.
struct SessionsGettingStartedView: View {
    let onStart: (() -> Void)?

    private let steps: [(title: String, detail: String)] = [
        ("Pick a bot", "Each bot keeps its own skills and memory."),
        ("Say what you need", "Type, talk, or attach a photo or file."),
        ("Get notified when it's done", "Work keeps going while you're away."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: BighelpTokens.space24) {
            VStack(alignment: .leading, spacing: BighelpTokens.space12) {
                Text("Your first chat")
                    .font(.bighelp(.footnote).weight(.semibold))
                    .foregroundStyle(theme.action)
                Text("Ask for anything.\nYour bot takes it from there.")
                    .font(.bighelp(.title2).bold())
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let onStart {
                    Button(action: onStart) {
                        Label("New chat", systemImage: "square.and.pencil")
                            .font(.bighelp(.body).weight(.semibold))
                            .padding(.horizontal, BighelpTokens.space8)
                            .frame(minHeight: BighelpTokens.hitTarget)
                    }
                    .bighelpProminentButtonStyle()
                    .buttonBorderShape(.capsule)
                    .tint(theme.action)
                    .accessibilityIdentifier("sessions.empty.new-chat")
                }
            }
            .padding(BighelpTokens.space20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: .rect(cornerRadius: BighelpTokens.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BighelpTokens.cardCornerRadius, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: BighelpTokens.hairline)
            }

            VStack(alignment: .leading, spacing: BighelpTokens.space12) {
                Text("How it works")
                    .font(.bighelp(.headline))
                    .foregroundStyle(theme.primaryText)
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: BighelpTokens.space12) {
                        Text("\(index + 1)")
                            .font(.bighelp(.headline))
                            .foregroundStyle(theme.action)
                            .frame(width: 40, height: 40)
                            .background(theme.incomingMessageBackground, in: .circle)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.bighelp(.subheadline).weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                            Text(step.detail)
                                .font(.bighelp(.subheadline))
                                .foregroundStyle(theme.secondaryText)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(BighelpTokens.space12)
                    .overlay {
                        RoundedRectangle(cornerRadius: BighelpTokens.radius16, style: .continuous)
                            .strokeBorder(theme.border, lineWidth: BighelpTokens.hairline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Step \(index + 1): \(step.title). \(step.detail)")
                }
            }
        }
        .padding(.vertical, BighelpTokens.space8)
        .accessibilityElement(children: .contain)
    }

    @BighelpThemeReader private var theme
}

/// Where a chat started (Telegram, Codex, Hermes Desktop…), as a small tag. Nothing when Hermes didn't say.
struct SessionOriginTag: View {
    let source: String?
    var size: CGFloat = 13

    var body: some View {
        if let origin = SessionOrigin.label(source) {
            SessionRowChip(text: origin, size: size)
                .accessibilityLabel("Started in \(origin)")
        }
    }
}

/// A small capsule of plain text on a chat row or a list: where a chat started, its project,
/// and the rest of the tags Settings › Appearance › Chat rows offers.
struct SessionRowChip: View {
    let text: String
    var size: CGFloat = 13

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(theme.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(theme.incomingMessageBackground, in: .capsule)
            .fixedSize()
    }

    @BighelpThemeReader private var theme
}

/// One more tag a chat row can carry (Settings › Appearance › Chat rows). Every case reads a
/// field `SessionSummary` already has, so a row never asks the host for anything new.
enum SessionRowDetail: String, CaseIterable, Codable, Identifiable, Sendable {
    case origin
    case project
    case scheduled
    case group
    case agents

    var id: Self { self }

    /// The name in Settings.
    var title: String {
        switch self {
        case .origin: String(localized: "Where it started")
        case .project: String(localized: "Project")
        case .scheduled: String(localized: "Scheduled")
        case .group: String(localized: "Group")
        case .agents: String(localized: "Agent names")
        }
    }

    /// What the tag says on a row, as Settings describes it.
    var detail: String {
        switch self {
        case .origin: String(localized: "Telegram, Codex, Hermes Desktop and the rest")
        case .project: String(localized: "The chat's project, when it's in one")
        case .scheduled: String(localized: "A chat a scheduled task started")
        case .group: String(localized: "A chat with more than one agent")
        case .agents: String(localized: "Every agent's name in a group chat")
        }
    }

    var symbol: String {
        switch self {
        case .origin: "arrow.up.forward.app"
        case .project: "folder"
        case .scheduled: "clock.arrow.circlepath"
        case .group: "person.2"
        case .agents: "person.2.badge.gearshape"
        }
    }
}

/// Where the tags sit on a row.
enum SessionRowChipPlacement: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Beside the preview, where the tag for where a chat started has always been.
    case besidePreview
    /// On a line of their own under the title, which keeps the preview whole.
    case abovePreview

    var id: Self { self }

    var title: String {
        switch self {
        case .besidePreview: String(localized: "Beside the preview")
        case .abovePreview: String(localized: "On their own line")
        }
    }
}

/// What a chat row shows, saved as JSON text (Settings › Appearance › Chat rows).
/// `.standard` is exactly the row bighelp draws by default: the tag for where a chat started,
/// beside its preview, with its time.
struct SessionRowLayout: Equatable, Sendable {
    /// UserDefaults' key, beside the rest of the chat list's look.
    static let key = "bighelp.chat-list.row-layout"
    /// A row's text column is narrow on a phone; three tags leave the preview room to read.
    static let maximumChips = 3
    /// A project or a run of agent names is bounded so its tag never crowds the rest of the row.
    static let maximumChipText = 24

    /// The tags the row shows, in the order it shows them.
    private(set) var chips: [SessionRowDetail]
    var placement: SessionRowChipPlacement
    var showsPreview: Bool
    var showsTime: Bool

    static let standard = SessionRowLayout(chips: [.origin])

    init(chips: [SessionRowDetail],
         placement: SessionRowChipPlacement = .besidePreview,
         showsPreview: Bool = true,
         showsTime: Bool = true) {
        var seen = Set<SessionRowDetail>()
        self.chips = Array(chips.filter { seen.insert($0).inserted }.prefix(Self.maximumChips))
        self.placement = placement
        self.showsPreview = showsPreview
        self.showsTime = showsTime
    }

    func isShown(_ detail: SessionRowDetail) -> Bool { chips.contains(detail) }

    var canShowMore: Bool { chips.count < Self.maximumChips }

    mutating func show(_ detail: SessionRowDetail) {
        guard canShowMore, !chips.contains(detail) else { return }
        chips.append(detail)
    }

    mutating func hide(_ detail: SessionRowDetail) {
        chips.removeAll { $0 == detail }
    }

    /// Drags a tag to a new place in the row. A tag Settings doesn't list can't arrive here.
    mutating func moveChips(from source: IndexSet, to destination: Int) {
        chips.move(fromOffsets: source, toOffset: destination)
    }

    /// Shortens a tag's text to what a row can carry, ending it with an ellipsis.
    nonisolated static func bounded(_ text: String) -> String {
        guard text.count > maximumChipText else { return text }
        return String(text.prefix(maximumChipText - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Saved as JSON text; anything unreadable is the standard row.
    init(saved text: String?) {
        guard let text, text.utf8.count <= 2_048,
              let raw = try? JSONDecoder().decode(Raw.self, from: Data(text.utf8)) else {
            self = .standard
            return
        }
        self.init(chips: raw.chips.compactMap(SessionRowDetail.init(rawValue:)),
                  placement: SessionRowChipPlacement(rawValue: raw.placement) ?? .besidePreview,
                  showsPreview: raw.preview,
                  showsTime: raw.time)
    }

    var saved: String? {
        let raw = Raw(chips: chips.map(\.rawValue), placement: placement.rawValue,
                      preview: showsPreview, time: showsTime)
        return (try? JSONEncoder().encode(raw)).flatMap { String(data: $0, encoding: .utf8) }
    }

    private struct Raw: Codable {
        let chips: [String]
        let placement: String
        let preview: Bool
        let time: Bool
    }
}
