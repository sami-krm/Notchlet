import SwiftUI
import XCTest
@testable import DynamicNotch

private struct BriefActivity: Activity {
    let id: String
    var displayDuration: TimeInterval = 60
    var closedView: AnyView { AnyView(EmptyView()) }
}

@MainActor
final class ActivityQueueTests: XCTestCase {
    private func makeViewModel() -> NotchViewModel {
        NotchViewModel(geometry: NotchGeometry(notchSize: CGSize(width: 200, height: 32), hasNotch: true))
    }

    func testNothingDisplayedWithoutActivity() {
        XCTAssertNil(makeViewModel().displayed)
    }

    func testBriefActivityReplacesMusicThenMusicComesBack() {
        let vm = makeViewModel()
        vm.media.handle(["Player State": "Playing", "Name": "Titre"], bundleID: "com.spotify.client")
        XCTAssertEqual(vm.displayed?.id, "music")

        vm.enqueue(BriefActivity(id: "brief"))
        XCTAssertEqual(vm.displayed?.id, "brief")

        vm.finishCurrentTransient()
        XCTAssertEqual(vm.displayed?.id, "music")
    }

    func testBriefActivitiesFollowArrivalOrder() {
        let vm = makeViewModel()
        vm.enqueue(BriefActivity(id: "first"))
        vm.enqueue(BriefActivity(id: "second"))
        XCTAssertEqual(vm.displayed?.id, "first")

        vm.finishCurrentTransient()
        XCTAssertEqual(vm.displayed?.id, "second")

        vm.finishCurrentTransient()
        XCTAssertNil(vm.displayed)
    }

    func testBriefActivityEndsOnItsOwn() {
        let vm = makeViewModel()
        vm.enqueue(BriefActivity(id: "first", displayDuration: 0.01))
        vm.enqueue(BriefActivity(id: "second", displayDuration: 0.01))

        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        XCTAssertNil(vm.displayed)
    }
}
