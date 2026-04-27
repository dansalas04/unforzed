import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// ─── EndMatchView ─────────────────────────────────────────────────────────────
// Confirmation screen: START = confirm, BACK = cancel.

class EndMatchView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 30 / 100, Graphics.FONT_MEDIUM,
            "¿Terminar partido?",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(0x00CC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 52 / 100, Graphics.FONT_SMALL,
            "START = sí",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 68 / 100, Graphics.FONT_SMALL,
            "BACK = no",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// ─── EndMatchDelegate ─────────────────────────────────────────────────────────

class EndMatchDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        // Save match to local storage
        StorageModel.saveMatch(getModel().toSummaryDict());
        // Show final summary — replace the whole stack with it
        WatchUi.switchToView(new FinalSummaryView(), new FinalSummaryDelegate(),
                             WatchUi.SLIDE_LEFT);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
