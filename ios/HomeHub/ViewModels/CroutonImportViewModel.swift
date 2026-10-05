import Foundation

/// Runs an import of a Crouton export: reads the files, sends the recipes in small batches, then
/// sends each new recipe's photo, resized. Importing the same export again is safe: the server
/// recognises recipes it already has and skips them.
@MainActor
final class CroutonImportViewModel: ObservableObject {
    enum Phase: Equatable {
        case choosing
        case working
        case finished
    }

    struct Problem: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let reason: String
    }

    @Published private(set) var phase: Phase = .choosing
    @Published private(set) var total = 0
    @Published private(set) var processed = 0
    @Published private(set) var currentTitle = ""
    @Published private(set) var created = 0
    @Published private(set) var duplicates = 0
    @Published private(set) var photosSaved = 0
    @Published private(set) var photosFailed = 0
    @Published private(set) var problems: [Problem] = []
    /// Set when photos can't be stored at all (the server isn't set up for it), so the summary says why.
    @Published private(set) var photoNote: String?
    @Published private(set) var wasCancelled = false
    /// The import gave up because every further batch would fail the same way (an old server, being
    /// signed out), as opposed to the person stopping it or some recipes being unreadable.
    @Published private(set) var stoppedEarly = false
    @Published private(set) var message: String?

    var isRunning: Bool { phase == .working }

    private weak var appState: AppState?
    private var task: Task<Void, Never>?
    private var photosEnabled = true

    private static let batchSize = 10
    private static let photoConcurrency = 3
    private static let stopAfterFailedBatches = 3

    func bind(to appState: AppState) {
        self.appState = appState
    }

    /// Starts importing what the person picked: any mix of folders and `.crumb` files.
    func start(picked urls: [URL]) {
        guard phase != .working, let appState else { return }
        reset()
        phase = .working
        let api = appState.api
        task = Task { [weak self] in
            await self?.run(urls: urls, api: api)
        }
    }

    func cancel() {
        guard phase == .working else { return }
        wasCancelled = true
        task?.cancel()
    }

    func startOver() {
        guard phase == .finished else { return }
        reset()
    }

    private func reset() {
        phase = .choosing
        total = 0
        processed = 0
        currentTitle = ""
        created = 0
        duplicates = 0
        photosSaved = 0
        photosFailed = 0
        problems = []
        photoNote = nil
        wasCancelled = false
        stoppedEarly = false
        message = nil
        photosEnabled = true
    }

    // MARK: The import

    private func run(urls: [URL], api: HomeHubAPI) async {
        let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
        defer { scoped.forEach { $0.stopAccessingSecurityScopedResource() } }

        let files = await Task.detached { CroutonImport.crumbFiles(in: urls) }.value
        total = files.count
        guard !files.isEmpty else {
            message = "No Crouton recipes were found in what you chose. Pick the folder of .crumb files, or the files themselves."
            phase = .finished
            return
        }

        var failedBatches = 0
        var index = 0
        while index < files.count, !Task.isCancelled {
            let batch = Array(files[index..<min(index + Self.batchSize, files.count)])
            index += batch.count
            currentTitle = batch.first?.deletingPathExtension().lastPathComponent ?? ""

            let read = await Task.detached { Self.read(batch) }.value
            for failure in read.unreadable {
                problems.append(Problem(title: failure.name, reason: "This file couldn't be read as a Crouton recipe."))
            }

            if !read.recipes.isEmpty {
                do {
                    let response = try await api.importCroutonRecipes(read.recipes.map(\.recipe))
                    failedBatches = 0
                    await handle(response, for: read.recipes, api: api)
                } catch {
                    failedBatches += 1
                    let reason = error.userFacingMessage ?? "The import was interrupted."
                    for item in read.recipes {
                        problems.append(Problem(title: item.recipe.name, reason: reason))
                    }
                    if failedBatches >= Self.stopAfterFailedBatches || Self.isFatal(error) {
                        message = reason
                        stoppedEarly = true
                        processed = total
                        break
                    }
                }
            }
            processed = min(total, processed + batch.count)
        }

        phase = .finished
    }

    private func handle(
        _ response: CroutonImportResponse,
        for items: [ReadRecipe],
        api: HomeHubAPI
    ) async {
        var photoJobs: [(id: String, photo: String)] = []
        for result in response.results {
            guard items.indices.contains(result.index) else { continue }
            switch result.status {
            case .created:
                created += 1
                if let id = result.id, let photo = items[result.index].photoBase64 {
                    photoJobs.append((id, photo))
                }
            case .duplicate:
                duplicates += 1
                // Imported earlier without its photo (photo storage wasn't set up yet): send it now.
                if result.hasPhoto == false, let id = result.id, let photo = items[result.index].photoBase64 {
                    photoJobs.append((id, photo))
                }
            case .failed:
                problems.append(Problem(title: result.title, reason: result.error ?? "This recipe couldn't be imported."))
            }
        }
        await upload(photoJobs, api: api)
    }

    /// Sends photos a few at a time. Resizing happens off the main thread.
    private func upload(_ jobs: [(id: String, photo: String)], api: HomeHubAPI) async {
        guard photosEnabled, !jobs.isEmpty else { return }
        var pending = jobs[...]

        await withTaskGroup(of: PhotoOutcome.self) { group in
            func addNext() {
                guard let job = pending.popFirst() else { return }
                group.addTask {
                    guard let jpeg = CroutonImport.photoJPEG(fromBase64: job.photo) else { return .unreadable }
                    do {
                        try await api.uploadRecipePhoto(recipeId: job.id, jpeg: jpeg)
                        return .saved
                    } catch {
                        return .failed(error.userFacingMessage ?? "")
                    }
                }
            }
            for _ in 0..<Self.photoConcurrency { addNext() }

            for await outcome in group {
                switch outcome {
                case .saved:
                    photosSaved += 1
                case .unreadable:
                    photosFailed += 1
                case .failed(let reason):
                    if reason.localizedCaseInsensitiveContains("not configured") {
                        // Every remaining upload would fail the same way, so stop trying.
                        photosEnabled = false
                        photoNote = "Photos couldn't be saved because photo storage isn't set up on the server. The recipes were added without them."
                        pending.removeAll()
                    } else {
                        photosFailed += 1
                    }
                }
                if photosEnabled, !Task.isCancelled { addNext() }
            }
        }
    }

    private enum PhotoOutcome: Sendable {
        case saved
        case unreadable
        case failed(String)
    }

    // MARK: Reading files

    struct ReadRecipe: Sendable {
        let recipe: CroutonRecipePayload
        let photoBase64: String?
    }

    nonisolated private static func read(_ urls: [URL]) -> (recipes: [ReadRecipe], unreadable: [(name: String, url: URL)]) {
        var recipes: [ReadRecipe] = []
        var unreadable: [(name: String, url: URL)] = []
        for url in urls {
            if let file = try? CroutonImport.parse(url) {
                recipes.append(ReadRecipe(recipe: file.recipe, photoBase64: file.photoBase64))
            } else {
                unreadable.append((url.deletingPathExtension().lastPathComponent, url))
            }
        }
        return (recipes, unreadable)
    }

    /// Errors where trying the next batch can only fail the same way.
    private static func isFatal(_ error: Error) -> Bool {
        if case APIError.unauthorized = error { return true }
        if let api = error as? APIError, case .serverError(let message) = api {
            return message.localizedCaseInsensitiveContains("permission") || message.localizedCaseInsensitiveContains("too many")
        }
        return false
    }
}
