import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = CalendarViewModel()
    @State private var showCalendarSettings = false
    @State private var didApplyCompactDefault = false
    @AppStorage(NativeCalendarPreferenceKeys.agendaFontSize) private var agendaFontSize = 15.0
    @AppStorage(NativeCalendarPreferenceKeys.useSystemAgendaFont) private var useSystemAgendaFont = true

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                ScrollView {
                    content
                }
            } else {
                content
            }
        }
        .onAppear {
            viewModel.bind(to: appState)
            applyCompactDefaultViewMode()
            viewModel.startAutoSync(appState: appState)
        }
        .task(id: taskKey) {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .sheet(isPresented: $showCalendarSettings) {
            NavigationStack {
                ScrollView {
                    CalendarSettingsView()
                        .padding(24)
                        .environmentObject(appState)
                }
                .navigationTitle("Calendar & Reminders")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showCalendarSettings = false }
                    }
                }
            }
        }
        .onDisappear {
            viewModel.stopAutoSync()
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
            if horizontalSizeClass == .compact {
                VStack(alignment: .leading, spacing: 16) {
                    mainCalendar
                    agendaPanel
                }
            } else {
                HStack(alignment: .top, spacing: 20) {
                    mainCalendar
                        .frame(maxWidth: .infinity)
                    agendaPanel
                        .frame(width: 320)
                }
            }
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
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private var calendarSourceAndActions: some View {
        HStack(spacing: 8) {
            Text(viewModel.calendarSourceLabel)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(HubTheme.sunSoft)
                .clipShape(Capsule())

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
        Picker("View", selection: Binding(
            get: { viewModel.viewMode },
            set: { viewModel.setViewMode($0) }
        )) {
            ForEach(CalendarViewMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var calendarSearchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(HubTheme.muted)
            TextField("Search events…", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var calendarNavigationControls: some View {
        HStack(spacing: 12) {
            Button { viewModel.goPrevious() } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(HubButtonStyle(emphasis: .secondary))

            Button("Today") { viewModel.goToToday() }
                .buttonStyle(HubButtonStyle(emphasis: .secondary))

            Button { viewModel.goNext() } label: {
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
                    CalendarDayTimelineView(viewModel: viewModel)
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
            .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .compact ? 18 : 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: horizontalSizeClass == .compact ? 18 : 24, style: .continuous)
                    .stroke(HubTheme.line, lineWidth: 1)
            )
    }

    private var agendaPanel: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AGENDA")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(HubTheme.muted)
                        Text(CalendarHelpers.agendaTitle(viewModel.selectedDate, timezone: viewModel.timezone))
                            .font(.title3.weight(.semibold))
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

                if viewModel.selectedDayEvents.isEmpty {
                    EmptyStateView(text: viewModel.searchQuery.isEmpty ? "No events on this day" : "Try clearing your search.")
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(viewModel.selectedDayEvents) { event in
                                CalendarAgendaEventRow(
                                    event: event,
                                    timezone: viewModel.timezone,
                                    titleFont: agendaEventFont,
                                    canManage: viewModel.canManage,
                                    canEditBirthday: canEditBirthday(for: event),
                                    isExpanded: viewModel.editingEvent?.id == event.id,
                                    editableCalendars: viewModel.editableCalendars(for: event),
                                    onEdit: { viewModel.editingEvent = event },
                                    onEditBirthday: { profileId in
                                        appState.openProfileEdit(profileId: profileId)
                                        viewModel.editingEvent = nil
                                    },
                                    onUpdate: { input in
                                        await viewModel.updateEvent(id: event.eventId, input: input)
                                    },
                                    onDelete: {
                                        await viewModel.deleteEvent(id: event.eventId)
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 360)
                }

                if viewModel.supportsServerEventEditing {
                    if viewModel.isConnected, !viewModel.calendars.isEmpty {
                        DisclosureGroup("Add an event", isExpanded: $viewModel.showAddEvent) {
            CalendarEventFormView(
                calendars: viewModel.calendars,
                timezone: viewModel.timezone,
                submitLabel: "Add event",
                defaultSelectedDate: viewModel.selectedDate,
                preferredCalendarId: appState.nativeCalendar.defaultCalendarForNewEvents?.calendarIdentifier
            ) { input in
                                await viewModel.createEvent(input)
                            }
                        }
                        .font(.subheadline.weight(.bold))
                    } else {
                        VStack(spacing: 8) {
                            Text("Connect a calendar to add and edit events.")
                                .font(.footnote)
                                .foregroundStyle(HubTheme.muted)
                                .multilineTextAlignment(.center)
                            Button("Connect calendars") {
                                showCalendarSettings = true
                            }
                            .buttonStyle(HubButtonStyle(emphasis: .secondary))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                } else if viewModel.usesNativeCalendar {
                    Text("Events are coming directly from this device's calendars.")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
        }
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

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label.uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(HubTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compactLayout ? 5 : 8)
                }

                ForEach(viewModel.gridDates, id: \.timeIntervalSince1970) { day in
                    let localDate = CalendarHelpers.localDate(for: day, timezone: viewModel.timezone)
                    CalendarDayCell(
                        date: day,
                        localDate: localDate,
                        events: viewModel.events(on: localDate),
                        timezone: viewModel.timezone,
                        isSelected: localDate == viewModel.selectedDate,
                        isToday: localDate == viewModel.today,
                        isOutsideMonth: viewModel.viewMode == .month && !CalendarHelpers.isSameMonth(day, anchor: viewModel.anchorDate, timezone: viewModel.timezone),
                        compact: compactLayout || viewModel.viewMode == .month,
                        showsEventLabels: !compactLayout,
                        onSelect: { viewModel.selectDate(localDate) }
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

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
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

                if showsEventLabels {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(events.prefix(compact ? 3 : 8)) { event in
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
                        if events.count > (compact ? 3 : 8) {
                            Text("+\(events.count - (compact ? 3 : 8)) more")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(HubTheme.muted)
                        }
                    }
                } else if !events.isEmpty {
                    compactEventDots
                }
                Spacer(minLength: 0)
            }
            .padding(compact ? 4 : 6)
            .frame(maxWidth: .infinity, minHeight: compact ? 58 : 520, alignment: .topLeading)
            .background(isSelected ? HubTheme.sunSoft.opacity(0.35) : Color.clear)
            .opacity(isOutsideMonth ? 0.55 : 1)
        }
        .buttonStyle(.plain)
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

    private let hours = Array(6...22)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text(CalendarHelpers.agendaTitle(viewModel.selectedDate, timezone: viewModel.timezone))
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

            let allDay = viewModel.selectedDayEvents.filter(\.allDay)
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

            ForEach(hours, id: \.self) { hour in
                HStack(alignment: .top, spacing: 12) {
                    Text(CalendarHelpers.hourLabel(hour, selectedDate: viewModel.selectedDate, timezone: viewModel.timezone))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .frame(width: 52, alignment: .trailing)
                    VStack(spacing: 8) {
                        ForEach(viewModel.selectedDayEvents.filter { !$0.allDay && CalendarHelpers.eventHour($0, timezone: viewModel.timezone) == hour }) { event in
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

            if viewModel.selectedDayEvents.isEmpty {
                EmptyStateView(text: "Nothing scheduled")
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
                    .font(.subheadline.weight(.bold))
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

private struct CalendarAgendaEventRow: View {
    let event: CalendarOccurrence
    let timezone: TimeZone
    var titleFont: Font = .subheadline.weight(.heavy)
    let canManage: Bool
    let canEditBirthday: Bool
    let isExpanded: Bool
    let editableCalendars: [CalendarPickerOption]
    let onEdit: () -> Void
    let onEditBirthday: (String) -> Void
    let onUpdate: (CalendarEventFormInput) async -> Bool
    let onDelete: () async -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(titleFont)
                        .foregroundStyle(.primary)
                    Text(detailLine)
                        .font(.caption)
                        .foregroundStyle(HubTheme.muted)
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundStyle(HubTheme.muted)
                    }
                    if let description = event.description, !description.isEmpty {
                        Text(description)
                            .font(.caption2)
                            .foregroundStyle(HubTheme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if isExpanded, !event.isBirthday, canManage, !editableCalendars.isEmpty {
                CalendarEventFormView(
                    calendars: editableCalendars,
                    timezone: timezone,
                    submitLabel: "Save changes",
                    event: event,
                    defaultSelectedDate: CalendarHelpers.localDate(for: event.startsAt, timezone: timezone),
                    onSubmit: onUpdate,
                    onDelete: onDelete
                )
            } else if isExpanded, event.isBirthday {
                if canEditBirthday, let profileId = event.profileId {
                    Button("Edit birthday") {
                        onEditBirthday(profileId)
                    }
                    .buttonStyle(HubButtonStyle(emphasis: .primary))
                } else {
                    Text("Birthdays are edited from a family member's profile.")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                }
            }
        }
        .padding(12)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1)
                .fill(HubTheme.profileColor(event.color))
                .frame(width: 4)
        }
    }

    private var detailLine: String {
        let time = event.allDay
            ? "All day"
            : DateHelpers.timeString(event.startsAt, timezone: timezone)
        return "\(time) · \(event.calendarName)"
    }
}
