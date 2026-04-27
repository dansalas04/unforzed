import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// ─── SetupView ────────────────────────────────────────────────────────────────
// Modes:
//   :position  — 2 steps: position then who serves (initial match start)
//   :newSet    — 1 step: only who serves (used at start of each new set)
//
// Navigation: UP/DOWN to select, START to confirm, BACK exits (only in :newSet)

class SetupView extends WatchUi.View {

    // :position or :newSet
    var mode as Symbol;
    // 0 = position step, 1 = who-serves step
    var step as Number = 0;
    // Selected option index (0 or 1) for the current step
    var selectedOption as Number = 0;
    // Which set we're configuring (shown in title for :newSet mode)
    var targetSet as Number = 1;

    function initialize(m as Symbol) {
        View.initialize();
        mode = m;
        if (mode == :newSet) {
            step = 1; // skip position step
            targetSet = getModel().currentSet;
        }
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Title
        var title = _getTitle();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 5, Graphics.FONT_SMALL, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Two options
        var opt0 = _getOption(0);
        var opt1 = _getOption(1);

        _drawOption(dc, cx, cy - h / 8, opt0, selectedOption == 0);
        _drawOption(dc, cx, cy + h / 8, opt1, selectedOption == 1);

        // Hint
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 4 / 5, Graphics.FONT_XTINY,
            "UP/DOWN  ·  START=ok",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawOption(dc as Graphics.Dc, x as Number, y as Number,
                         label as String, selected as Boolean) as Void {
        if (selected) {
            // Highlight pill
            var tw = dc.getTextWidthInPixels(label, Graphics.FONT_MEDIUM) + 20;
            dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x - tw / 2, y - 18, tw, 36, 8);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(x, y, Graphics.FONT_MEDIUM, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _getTitle() as String {
        if (step == 0) {
            return WatchUi.loadResource(Rez.Strings.SetupPositionTitle) as String;
        }
        if (mode == :newSet) {
            return Lang.format(
                WatchUi.loadResource(Rez.Strings.SetupServeNewSetTitle) as String,
                [targetSet]
            );
        }
        return WatchUi.loadResource(Rez.Strings.SetupServeTitle) as String;
    }

    function _getOption(idx as Number) as String {
        if (step == 0) {
            return idx == 0
                ? (WatchUi.loadResource(Rez.Strings.SetupDrive) as String)
                : (WatchUi.loadResource(Rez.Strings.SetupReves) as String);
        }
        return idx == 0
            ? (WatchUi.loadResource(Rez.Strings.SetupNosotros) as String)
            : (WatchUi.loadResource(Rez.Strings.SetupEllos) as String);
    }

    // Called by delegate to cycle option
    function moveSelection(delta as Number) as Void {
        selectedOption = (selectedOption + delta + 2) % 2;
        WatchUi.requestUpdate();
    }

    // Called by delegate on START press; returns true if wizard is complete
    function confirmSelection() as Boolean {
        if (step == 0) {
            // Save position
            getModel().posicion = (selectedOption == 0) ? POS_DRIVE : POS_REVES;
            // Advance to step 1
            step = 1;
            selectedOption = 0;
            WatchUi.requestUpdate();
            return false; // not done yet
        }

        // Step 1: who serves
        var weSacamos = (selectedOption == 0); // NOSOTROS = index 0
        if (mode == :newSet) {
            getModel().initNewSet(weSacamos);
        } else {
            // :position mode — initMatch called here with the position already set
            getModel().initMatch(getModel().posicion, weSacamos);
        }
        return true; // wizard complete → caller pushes dashboard
    }
}

// ─── SetupDelegate ────────────────────────────────────────────────────────────

class SetupDelegate extends WatchUi.BehaviorDelegate {

    var _view as SetupView;

    function initialize(view as SetupView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onPreviousPage() as Boolean {
        _view.moveSelection(-1);
        return true;
    }

    function onNextPage() as Boolean {
        _view.moveSelection(1);
        return true;
    }

    function onSelect() as Boolean {
        var done = _view.confirmSelection();
        if (done) {
            // Replace setup with dashboard (no back navigation to setup)
            WatchUi.switchToView(
                new DashboardView(),
                new DashboardDelegate(),
                WatchUi.SLIDE_LEFT
            );
        }
        return true;
    }

    function onBack() as Boolean {
        // Allow back only in newSet mode (user can cancel the set prompt)
        if (_view.mode == :newSet) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
    }
}
