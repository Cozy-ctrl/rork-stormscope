import WidgetKit
import SwiftUI

@main
struct StormScopeWidgetBundle: WidgetBundle {
    var body: some Widget {
        StormScopeWidget()
        StormScopeLiveActivity()
    }
}
