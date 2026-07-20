import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CalendarViewModel()
    @State private var showCalendarSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            controls
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }
            HStack(alignment: .top, spacing: 20) {
                mainCalendar
                    .frame(maxWidth: .infinity)
                agendaPanel
                    .frame(width: 320)
            }
        }
        .onAppear {
            viewModel.bind(to: appState)
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
                .navigationTitle("Calendars")
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

    private func canEditBirthday(for event: CalendarOccurrence) -> Bool {
        guard event.isBirthday, let profileId = event.profileId else { return false }
        return appState.canEditProfile(profileId, profiles: appState.dashboard?.profiles ?? [])
    }

    private var taskKey: String {
        "\(viewModel.viewMode.rawValue)-\(viewModel.anchorDate.timeIntervalSince1970)-\(viewModel.searchQuery)"
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Everyone, all in one place")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(HubTheme.sage)
                Text("Family calendar")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
            }
            Spacer()
            if viewModel.canManage {
                Button {
                    Task { await viewModel.syncCalendars() }
                } label: {
                    if viewModel.isSyncing {
                        ProgressView()
                    } else {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("View", selection: Binding(
                get: { viewModel.viewMode },
                set: { viewModel.setViewMode($0) }
            )) {
                ForEach(CalendarViewMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

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
            .frame(maxWidth: 280)

            Spacer()

            Button { viewModel.goPrevious() } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.bordered)

            Button("Today") { viewModel.goToToday() }
                .buttonStyle(.bordered)

            Button { viewModel.goNext() } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var mainCalendar: some View {
        HubCard {
            if viewModel.isLoading && viewModel.occurrences.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 420)
            } else {
                switch viewModel.viewMode {
                case .day:
                    CalendarDayTimelineView(viewModel: viewModel)
                default:
                    CalendarGridView(viewModel: viewModel)
                }
            }
        }
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

                if viewModel.canManage {
                    if viewModel.isConnected, !viewModel.calendars.isEmpty {
                        DisclosureGroup("Add an event", isExpanded: $viewModel.showAddEvent) {
                            CalendarEventFormView(
                                calendars: viewModel.calendars,
                                timezone: viewModel.timezone,
                                submitLabel: "Add event",
                                defaultSelectedDate: viewModel.selectedDate
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
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
}

private struct CalendarGridView: View {
    @ObservedObject var viewModel: CalendarViewModel

    private var weekdayLabels: [String] {
        WeekStart.weekdayLabels(weekStartsOn: viewModel.weekStartsOn)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.headerTitle)
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("Family")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(HubTheme.sunSoft)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 12)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label.uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(HubTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
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
                        compact: viewModel.viewMode == .month,
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
                Spacer(minLength: 0)
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: compact ? 112 : 520, alignment: .topLeading)
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
                        .font(.subheadline.weight(.heavy))
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
                    .buttonStyle(.borderedProminent)
                    .tint(HubTheme.sage)
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
