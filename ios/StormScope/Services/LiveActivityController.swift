import Foundation
import ActivityKit

/// Starts, updates (throttled to once per minute), and ends the lock screen
/// Live Activity showing the live pressure trend and storm status.
@Observable
final class LiveActivityController {
    private var activity: Activity<StormActivityAttributes>?
    private var lastUpdateAt: Date?

    var isRunning: Bool {
        activity != nil
    }

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(with state: StormActivityAttributes.ContentState) {
        guard activity == nil else {
            update(with: state, force: true)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Live Activities are disabled in Settings.")
            return
        }
        do {
            activity = try Activity.request(
                attributes: StormActivityAttributes(startedAt: Date()),
                content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(30 * 60))
            )
            lastUpdateAt = Date()
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }

    /// Pushes a new state at most once per minute unless forced (e.g. a
    /// tornado warning should never wait).
    func update(with state: StormActivityAttributes.ContentState, force: Bool = false) {
        guard let activity else { return }
        if !force, let lastUpdateAt, Date().timeIntervalSince(lastUpdateAt) < 60 {
            return
        }
        lastUpdateAt = Date()
        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: Date().addingTimeInterval(30 * 60))
            )
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Cleans up any activity left over from a previous app session.
    func adoptExistingActivity() {
        activity = Activity<StormActivityAttributes>.activities.first
    }
}
