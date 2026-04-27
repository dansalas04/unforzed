import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Lang;

// ─── SetSummaryView ───────────────────────────────────────────────────────────
// Auto-dismisses after 3 s. Shows stats for the set that just ended.
// After dismiss, pushes SetupView(:newSet) if the match is still ongoing,
// or FinalSummaryView if the match is over.

class SetSummaryView extends WatchUi.View {

    var _fbData   as Dictionary;
    var _timer    as Timer.Timer;
    var _setDict  as Dictionary;

    function initialize(fbData as Dictionary) {
        View.initialize();
        _fbData  = fbData;
        _setDict = fbData["setDict"] as Dictionary;
        _timer   = new Timer.Timer();
    }

    function onShow() as Void {
        _timer.start(method(:onTimerFired), 3000, false);
    }

    function onHide() as Void {
        _timer.stop();
    }

    function onTimerFired() as Void {
        _dismiss();
    }

    function _dismiss() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        var m = getModel();
        // Check if match is over (best of 3)
        if (m.setsGanados == 2 || m.setsPerdidos == 2) {
            WatchUi.pushView(new FinalSummaryView(), new FinalSummaryDelegate(),
                             WatchUi.SLIDE_LEFT);
        } else {
            // Start new set: ask who serves
            var sv = new SetupView(:newSet);
            WatchUi.pushView(sv, new SetupDelegate(sv), WatchUi.SLIDE_LEFT);
        }
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var m   = getModel();
        var w   = dc.getWidth();
        var h   = dc.getHeight();
        var cx  = w / 2;
        var jg  = _setDict["jg"] as Number;
        var jp  = _setDict["jp"] as Number;
        var tb  = (_setDict["tb"] as Number) == 1;
        var sn  = _setDict["set"] as Number;
        var won = jg > jp;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Header
        var hdrStr = tb
            ? ("SET " + sn + " · TIE-BREAK")
            : ("SET " + sn + " TERMINADO");
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 8, Graphics.FONT_TINY, hdrStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Big score
        dc.setColor(won ? Graphics.COLOR_WHITE : 0x888888,
                    Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 20, h * 35 / 100, Graphics.FONT_NUMBER_HOT,
            jg.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 35 / 100, Graphics.FONT_MEDIUM, "-",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(won ? 0x888888 : Graphics.COLOR_WHITE,
                    Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 20, h * 35 / 100, Graphics.FONT_NUMBER_HOT,
            jp.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Divider
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 50, h / 2, cx + 50, h / 2);

        // ENF + serve win stats for this set
        var enfSt  = m.enfForSet(sn);
        var sd     = m.serveWinData(); // full match — approximate for now
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 57 / 100, Graphics.FONT_XTINY,
            "ENF: " + enfSt,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx, h * 68 / 100, Graphics.FONT_XTINY,
            "c/s " + (sd["pctConSaque"] as Number) + "%   s/s " + (sd["pctSinSaque"] as Number) + "%",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Sets tally at the bottom
        var setsStr = m.setsGanados.toString() + " - " + m.setsPerdidos.toString();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 83 / 100, Graphics.FONT_MEDIUM, setsStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 92 / 100, Graphics.FONT_XTINY, "sets",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// ─── SetSummaryDelegate ───────────────────────────────────────────────────────
// Any key skips the timer.

class SetSummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var view = WatchUi.getCurrentView()[0] as SetSummaryView?;
        if (view instanceof SetSummaryView) {
            (view as SetSummaryView)._dismiss();
        }
        return true;
    }

    function onBack() as Boolean {
        return onKey(null);
    }
}
