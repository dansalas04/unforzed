import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Lang;

// ─── FeedbackView ─────────────────────────────────────────────────────────────
// Fullscreen color feedback shown for 1.5 s after any event.
// Auto-dismisses via Timer; delegate also allows manual dismiss.
// After dismiss, if fbData["setCompleted"] == true, shows SetSummaryView.

class FeedbackView extends WatchUi.View {

    var _fbData as Dictionary;
    var _timer  as Timer.Timer;

    function initialize(fbData as Dictionary) {
        View.initialize();
        _fbData = fbData;
        _timer  = new Timer.Timer();
    }

    function onShow() as Void {
        _timer.start(method(:onTimerFired), 1500, false);
    }

    function onHide() as Void {
        _timer.stop();
    }

    function onTimerFired() as Void {
        _dismiss();
    }

    function _dismiss() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        // If a set just completed, show set summary on top of dashboard
        if (_fbData.hasKey("setCompleted") && (_fbData["setCompleted"] as Boolean)) {
            WatchUi.pushView(
                new SetSummaryView(_fbData),
                new SetSummaryDelegate(),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (_fbData.hasKey("setCompleted") == false
                   || !(_fbData["setCompleted"] as Boolean)) {
            // Check if a new set needs serve setup
            // (setCompleted handled above; here we handle post-set-summary flow
            //  which is triggered from SetSummaryView itself)
        }
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var fbType = _fbData["fb"] as Number;

        // Background color
        var bgColor = _bgColor(fbType);
        dc.setColor(bgColor, bgColor);
        dc.clear();

        // Icon + label + sublabel
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var icon  = _icon(fbType);
        var label = _label(fbType);
        var sub   = _sublabel(fbType);

        dc.drawText(cx, cy - 30, Graphics.FONT_LARGE, icon,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx, cy + 15, Graphics.FONT_MEDIUM, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!sub.equals("")) {
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + 45, Graphics.FONT_XTINY, sub,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    function _bgColor(fbType as Number) as Number {
        switch (fbType) {
            case FB_GANADO:   return 0x1A4A2E;
            case FB_PERDIDO:  return 0x4A1A1A;
            case FB_ENF:      return 0x4A2E0A;
            case FB_SAQUE:    return 0x0A2A4A;
            case FB_DESHACER: return 0x2A2A2A;
        }
        return Graphics.COLOR_BLACK;
    }

    function _icon(fbType as Number) as String {
        switch (fbType) {
            case FB_GANADO:   return "✓";
            case FB_PERDIDO:  return "✗";
            case FB_ENF:      return "!" + (_fbData["enfCount"] as Number).toString();
            case FB_SAQUE:    return "◎";
            case FB_DESHACER: return "↩";
        }
        return "?";
    }

    function _label(fbType as Number) as String {
        switch (fbType) {
            case FB_GANADO:   return "GANADO";
            case FB_PERDIDO:  return "PERDIDO";
            case FB_ENF:      return "ENF";
            case FB_SAQUE:    return "SAQUE";
            case FB_DESHACER: return "DESHECHO";
        }
        return "";
    }

    function _sublabel(fbType as Number) as String {
        var m = getModel();
        if (fbType == FB_GANADO || fbType == FB_PERDIDO) {
            var gn  = _fbData["gameNum"] as Number;
            var sq  = _fbData["saque"] as Boolean;
            var sqStr = sq ? "con saque" : "sin saque";
            if (fbType == FB_PERDIDO) {
                var enf = _fbData["enf"] as Number;
                return enf > 0 ? (enf.toString() + " ENF este juego") : "";
            }
            return "Juego " + gn + " · " + sqStr;
        }
        if (fbType == FB_ENF) {
            return "este juego";
        }
        if (fbType == FB_SAQUE) {
            var gn  = (_fbData.hasKey("gameNum") ? _fbData["gameNum"] as Number : 0);
            var pos = m.posicion == POS_DRIVE ? "drive" : "revés";
            return "juego " + gn + " · " + pos;
        }
        if (fbType == FB_DESHACER) {
            var ut = _fbData["undoType"] as Number;
            switch (ut) {
                case UNDO_ENF:   return "ENF eliminado";
                case UNDO_SAQUE: return "saque eliminado";
                case UNDO_JUEGO: return "juego reabierto";
                case UNDO_NADA:  return "Nada que deshacer";
            }
        }
        return "";
    }
}

// ─── FeedbackDelegate ────────────────────────────────────────────────────────
// Any key press dismisses the feedback early.

class FeedbackDelegate extends WatchUi.BehaviorDelegate {

    var _fbData as Dictionary;

    function initialize(fbData as Dictionary) {
        BehaviorDelegate.initialize();
        _fbData = fbData;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        _earlyDismiss();
        return true;
    }

    function onBack() as Boolean {
        _earlyDismiss();
        return true;
    }

    function onSelect() as Boolean {
        _earlyDismiss();
        return true;
    }

    function _earlyDismiss() as Void {
        // Stop timer via the view reference — simplest way is to get current view
        var view = WatchUi.getCurrentView()[0] as FeedbackView?;
        if (view instanceof FeedbackView) {
            (view as FeedbackView)._dismiss();
        }
    }
}
