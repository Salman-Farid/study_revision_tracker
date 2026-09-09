import WidgetKit
import SwiftUI

@main
struct HomeWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyRoutineWidget()
        RevisionWidget()
        ClassRoutineWidget()
    }
}
