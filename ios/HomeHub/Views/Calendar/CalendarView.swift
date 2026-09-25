import Combine
import EventKit
import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = CalendarViewModel()
    @State private var showCalendarSettings = false
    @State private var didApplyCompactDefault = false
    @AppStorage(NativeCalendarPreferenceKeys.agendaFontSize) private var agendaFontSize = 15.0
    @AppStorage(NativeCalendarPreferenceKeys.useSystemAgendaFont) private var useSystemAgendaFont =
        true

    var body: some View {
        ScrollView {
            content
        }
        // Matches the system search behaviour of dropping the keyboard on scroll.
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            viewModel.bind(to: appState)
            applyCompactDefaultViewMode()
        }
        .task(id: taskKey) {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.load() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .debounce(for: .milliseconds(650), scheduler: RunLoop.main)) { _ in
                Task { await viewModel.load() }
            }
        .sheet(item: $viewModel.editingEvent) { event in
            CalendarEventDetailsView(
                event: event,
                timezone: viewModel.timezone,
                canEditBirthday: canEditBirthday(for: event),
                onEditBirthday: { profileId in
                    appState.openProfileEdit(profileId: profileId)
                }
            )
        }
        .sheet(
            isPresented: $showCalendarSettings,
            onDismiss: {
                Task { await viewModel.load() }
            }
        ) {
            NavigationStack {
                CalendarSettingsView()
                    .environmentObject(appState)
                    .navigationTitle("Calendar & Reminders")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showCalendarSettings = false }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            controls
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }
            nativeCalendarAccessBanner
            mainCalendar
        }
    }

    private var agendaEventFont: Font {
        useSystemAgendaFont
            ? .subheadline.weight(.heavy)
            : .system(size: CGFloat(agendaFontSize), weight: .heavy)
    }

    private func canEditBirthday(for event: CalendarOccurrence) -> Bool {
        guard event.isBirthday, let profileId = event.profileId else { return false }
        return appState.canEditProfile(profileId, profiles: appState.dashboard?.profiles ?? [])
    }

    private var taskKey: String {
        "\(viewModel.viewMode.rawValue)-\(viewModel.anchorDate.timeIntervalSince1970)-\(viewModel.searchQuery)"
    }

    private func applyCompactDefaultViewMode() {
        guard horizontalSizeClass == .compact, !didApplyCompactDefault else { return }
        didApplyCompactDefault = true
        viewModel.setViewMode(.day)
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom) {
                headerTitle
                Spacer()
                calendarSourceAndActions
            }
            VStack(alignment: .leading, spacing: 10) {
                headerTitle
                calendarSourceAndActions
            }
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Family calendar")
                .font(HubTheme.pageTitle)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private var calendarSourceAndActions: some View {
        HStack(spacing: 8) {
            Button {
                showCalendarSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2.weight(.semibold))
                    .frame(width: 52, height: 52)
                    .background(HubTheme.sageSoft, in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(HubTheme.sage)
            .accessibilityLabel("Calendar Settings")
            .help("Calendar Settings")

            if viewModel.needsNativeCalendarPermission {
                Button {
                    Task { await viewModel.requestNativeCalendarAccess() }
                } label: {
                    Label("Use Device Calendars", systemImage: "calendar.badge.checkmark")
                }
                .buttonStyle(HubButtonStyle(emphasis: .primary))
            }
        }
    }

    @ViewBuilder
    private var nativeCalendarAccessBanner: some View {
        if viewModel.nativeCalendarDenied {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(HubTheme.coral)
                Text("Calendar access is off. Turn it on in Settings to use local calendars.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HubTheme.muted)
                Spacer()
            }
            .padding(12)
            .background(HubTheme.tileQuiet)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if viewModel.needsNativeCalendarPermission {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundStyle(HubTheme.sage)
                Text("Use the calendars already on this device for a native schedule.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HubTheme.muted)
                Spacer()
                Button("Allow") {
                    Task { await viewModel.requestNativeCalendarAccess() }
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
            }
            .padding(12)
            .background(HubTheme.tileQuiet)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                calendarModePicker
                    .frame(maxWidth: 280)
                calendarSearchField
                    .frame(maxWidth: 280)
                Spacer()
                calendarNavigationControls
            }

            VStack(alignment: .leading, spacing: 10) {
                calendarModePicker
                calendarSearchField
                calendarNavigationControls
            }
        }
    }

    private var calendarModePicker: some View {
        Picker(
            "View",
            selection: Binding(
                get: { viewModel.viewMode },
                set: { viewModel.setViewMode($0) }
            )
        ) {
            ForEach(CalendarViewMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    // Hand-rolled rather than `.searchable` because this screen has no navigation
    // bar for the system field to render into. These modifiers reproduce the parts
    // of a system search field that affect behaviour rather than appearance.
    private var calendarSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(HubTheme.muted)
                .accessibilityHidden(true)

            TextField("Search events…", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityAddTraits(.isSearchField)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(HubTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.snappy(duration: 0.15), value: viewModel.searchQuery.isEmpty)
    }

    private var calendarNavigationControls: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.goPrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(HubButtonStyle(emphasis: .secondary))

            Button("Today") { viewModel.goToToday() }
                .buttonStyle(HubButtonStyle(emphasis: .secondary))

            Button {
                viewModel.goNext()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(HubButtonStyle(emphasis: .secondary))
        }
    }

    @ViewBuilder
    private var mainCalendar: some View {
        calendarSurface {
            if viewModel.isLoading && viewModel.occurrences.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 420)
            } else {
                switch viewModel.viewMode {
                case .day:
                    CalendarDayTimelineView(viewModel: viewModel, eventFont: agendaEventFont)
                default:
                    CalendarGridView(
                        viewModel: viewModel,
                        compactLayout: horizontalSizeClass == .compact
                    )
                }
            }
        }
    }

    private func calendarSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(horizontalSizeClass == .compact ? 12 : 20)
            .background(HubTheme.tile)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: horizontalSizeClass == .compact ? 18 : 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: horizontalSizeClass == .compact ? 18 : 24, style: .continuous
                )
                .stroke(HubTheme.line, lineWidth: 1)
            )
    }

}

private struct CalendarEventDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    let event: CalendarOccurrence
    let timezone: TimeZone
    let canEditBirthday: Bool
    let onEditBirthday: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(event.title)
                        .font(.title2.weight(.semibold))
                        .textSelection(.enabled)
                    LabeledContent("Calendar") {
                        Label {
                            Text(event.calendarName)
                        } icon: {
                            Circle()
                                .fill(HubTheme.profileColor(event.color))
                                .frame(width: 10, height: 10)
                        }
                    }
                    if event.allDay {
                        LabeledContent("Time", value: "All day")
                    }
                    LabeledContent("Starts", value: formattedDate(event.startsAt))
                    LabeledContent(
                        "Ends",
                        value: formattedDate(
                            event.allDay ? event.endsAt.addingTimeInterval(-1) : event.endsAt))
                    LabeledContent(
                        "Timezone",
                        value: timezone.identifier.replacingOccurrences(of: "_", with: " "))
                }
                if let location = event.location,
                    !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    Section("Location") {
                        Text(location).textSelection(.enabled)
                    }
                }
                if let notes = event.description,
                    !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    Section("Notes") {
                        Text(notes).textSelection(.enabled)
                    }
                }
                if event.isBirthday, canEditBirthday, let profileId = event.profileId {
                    Section {
                        Button("Edit Birthday") {
                            dismiss()
                            onEditBirthday(profileId)
                        }
                    }
                }
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateStyle = .medium
        formatter.timeStyle = event.allDay ? .none : .short
        return formatter.string(from: date)
    }
}

private struct CalendarGridView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let compactLayout: Bool

    private var weekdayLabels: [String] {
        WeekStart.weekdayLabels(weekStartsOn: viewModel.weekStartsOn)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.headerTitle)
                    .font((compactLayout ? Font.headline : Font.title2).weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
            }
            .padding(.bottom, compactLayout ? 8 : 12)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0
            ) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label.uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(HubTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compactLayout ? 5 : 8)
                }

                ForEach(viewModel.gridDates, id: \.timeIntervalSince1970) { day in
                    let localDate = CalendarHelpers.localDate(
                        for: day, timezone: viewModel.timezone)
                    CalendarDayCell(
                        date: day,
                        localDate: localDate,
                        events: viewModel.events(on: localDate),
                        timezone: viewModel.timezone,
                        isSelected: localDate == viewModel.selectedDate,
                        isToday: localDate == viewModel.today,
                        isOutsideMonth: viewModel.viewMode == .month
                            && !CalendarHelpers.isSameMonth(
                                day, anchor: viewModel.anchorDate, timezone: viewModel.timezone),
                        compact: compactLayout || viewModel.viewMode == .month,
                        showsEventLabels: !compactLayout,
                        onSelect: {
                            viewModel.selectDate(localDate)
                            viewModel.setViewMode(.day)
                        },
                        onSelectEvent: { viewModel.editingEvent = $0 }
                    )
                }
            }
        }
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let localDate: String
    let events: [CalendarOccurrence]
    let timezone: TimeZone
    let isSelected: Bool
    let isToday: Bool
    let isOutsideMonth: Bool
    let compact: Bool
    let showsEventLabels: Bool
    let onSelect: () -> Void
    let onSelectEvent: (CalendarOccurrence) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onSelect) {
                Text(dayNumber)
                    .font(.caption.weight(.heavy))
                    .frame(width: 28, height: 28)
                    .background(isToday ? HubTheme.sage : Color.clear)
                    .foregroundStyle(isToday ? .white : .primary)
                    .clipShape(Circle())
                    .overlay {
                        if isSelected && !isToday {
                            Circle().stroke(HubTheme.sage, lineWidth: 2)
                        }
                    }

            }
            .buttonStyle(.plain)
            .accessibilityLabel(CalendarHelpers.agendaTitle(localDate, timezone: timezone))

            if showsEventLabels {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(events.prefix(compact ? 3 : 8)) { event in
                        Button {
                            onSelectEvent(event)
                        } label: {
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(HubTheme.profileColor(event.color))
                                    .frame(width: 3)
                                Text(eventLabel(event))
                                    .font(.caption2.weight(.bold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(HubTheme.tileQuiet)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    if events.count > (compact ? 3 : 8) {
                        Button(action: onSelect) {
                            Text("+\(events.count - (compact ? 3 : 8)) more")
                        }
                        .buttonStyle(.plain)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                    }
                }
            } else if !events.isEmpty {
                Button(action: onSelect) { compactEventDots }
                    .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(compact ? 4 : 6)
        .frame(maxWidth: .infinity, minHeight: compact ? 58 : 520, alignment: .topLeading)
        .background(isSelected ? HubTheme.sunSoft.opacity(0.35) : Color.clear)
        .opacity(isOutsideMonth ? 0.55 : 1)
        .contentShape(Rectangle())
        .background {
            Button(action: onSelect) {
                Color.clear.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(CalendarHelpers.agendaTitle(localDate, timezone: timezone))
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(HubTheme.line).frame(width: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(HubTheme.line).frame(height: 1)
        }
    }

    private var dayNumber: String {
        let cal = CalendarHelpers.calendar(timezone: timezone, weekStartsOn: 1)
        return String(cal.component(.day, from: date))
    }

    private var compactEventDots: some View {
        HStack(spacing: 3) {
            ForEach(Array(events.prefix(3).enumerated()), id: \.element.id) { _, event in
                Circle()
                    .fill(HubTheme.profileColor(event.color))
                    .frame(width: 5, height: 5)
            }
            if events.count > 3 {
                Text("+\(events.count - 3)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(HubTheme.muted)
                    .lineLimit(1)
            }
        }
    }

    private func eventLabel(_ event: CalendarOccurrence) -> String {
        if event.allDay { return event.title }
        return "\(DateHelpers.timeString(event.startsAt, timezone: timezone)) \(event.title)"
    }
}

private struct CalendarDayTimelineView: View {
    @ObservedObject var viewModel: CalendarViewModel

    let eventFont: Font

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            timeline(now: context.date)
        }
    }

    private func timeline(now: Date) -> some View {
        let isToday = viewModel.selectedDate == DateHelpers.localDateIn(timezone: viewModel.timezone, date: now)
        let currentHour = CalendarHelpers.calendar(timezone: viewModel.timezone, weekStartsOn: viewModel.weekStartsOn).component(.hour, from: now)
        let firstHour = isToday ? currentHour : 0
        let events = CalendarHelpers.timelineEvents(viewModel.filteredOccurrences, on: viewModel.selectedDate, timezone: viewModel.timezone, now: now)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text(
                        CalendarHelpers.agendaTitle(
                            viewModel.selectedDate, timezone: viewModel.timezone)
                    )
                    .font(.title2.weight(.semibold))
                }
                Spacer()
                if viewModel.selectedDate == viewModel.today {
                    Text("Today")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(HubTheme.sunSoft)
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 12)

            let allDay = events.filter(\.allDay)
            if !allDay.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ALL DAY")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(HubTheme.muted)
                    ForEach(allDay) { event in
                        eventChip(event, showRange: false)
                    }
                }
                .padding(.bottom, 12)
            }

            ForEach(Array(firstHour...23), id: \.self) { hour in
                HStack(alignment: .top, spacing: 12) {
                    Text(
                        CalendarHelpers.hourLabel(
                            hour, selectedDate: viewModel.selectedDate, timezone: viewModel.timezone
                        )
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .frame(width: 52, alignment: .trailing)
                    VStack(spacing: 8) {
                        ForEach(
                            events.filter {
                                !$0.allDay && max(firstHour, displayHour(for: $0)) == hour
                            }
                        ) { event in
                            eventChip(event, showRange: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(HubTheme.line).frame(height: 1)
                }
            }

            if events.isEmpty {
                EmptyStateView(text: isToday ? "No more events today" : "Nothing scheduled")
            }
        }
    }

    @ViewBuilder
    private func eventChip(_ event: CalendarOccurrence, showRange: Bool) -> some View {
        Button {
            viewModel.editingEvent = event
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(eventFont)
                Text(subtitle(for: event, showRange: showRange))
                    .font(.caption)
                    .foregroundStyle(HubTheme.muted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HubTheme.tileQuiet)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(HubTheme.profileColor(event.color))
                    .frame(width: 4)
            }
        }
        .buttonStyle(.plain)
    }

    private func displayHour(for event: CalendarOccurrence) -> Int {
        let selectedDate =
            CalendarHelpers.parseLocalDate(viewModel.selectedDate, timezone: viewModel.timezone)
            ?? event.startsAt
        let calendar = CalendarHelpers.calendar(
            timezone: viewModel.timezone, weekStartsOn: viewModel.weekStartsOn
        )
        return calendar.component(.hour, from: max(calendar.startOfDay(for: selectedDate), event.startsAt))
    }

    private func subtitle(for event: CalendarOccurrence, showRange: Bool) -> String {
        if showRange {
            let start = DateHelpers.timeString(event.startsAt, timezone: viewModel.timezone)
            let end = DateHelpers.timeString(event.endsAt, timezone: viewModel.timezone)
            var text = "\(start) – \(end)"
            if let location = event.location, !location.isEmpty {
                text += " · \(location)"
            }
            return text
        }
        var text = event.calendarName
        if let location = event.location, !location.isEmpty {
            text += " · \(location)"
        }
        return text
    }
}
