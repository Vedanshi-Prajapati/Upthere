import WidgetKit
import SwiftUI

@main
struct UpthereWidgetsBundle: WidgetBundle {
    var body: some Widget {
        UpthereWeatherWidget()

        if #available(iOS 18.0, *) {
            UpthereQuickWeatherControl()
            UpthereAlertsControl()
        }

        RainStartActivityWidget()
    }
}
