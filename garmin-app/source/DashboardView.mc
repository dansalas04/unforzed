import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Attention;
import Toybox.Lang;

// ─── DashboardView ────────────────────────────────────────────────────────────
// 4-level visual hierarchy:
//   L1: set dots (●●○  ○○○)
//   L2: game score (big number)
//   L3: match metrics (ENF total, %ENF, %con saque, %sin saque)
//   L4: current-game indicators (serve rect + ENF dots)

class DashboardView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var m  = getModel();
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ── L1: set dots ──────────────────────────────────────────────────
        _drawSetDots(dc, cx, h / 10, m.setsGanados, m.setsPerdidos);

        // ── L2: game score ────────────────────────────────────────────────
        var scoreStr = m.juegosGanadosEnSet.toString() + " - "
                     + m.juegosPerdidosEnSet.toString();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 38 / 100, Graphics.FONT_NUMBER_HOT, scoreStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Set·game label
        var subLabel = "Set " + m.currentSet + "  ·  Juego "
                     + m.currentGameNumInSet;
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 53 / 100, Graphics.FONT_XTINY, subLabel,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── L3: metrics ───────────────────────────────────────────────────
        _drawMetrics(dc, cx, h, m);

        // ── L4: current game indicators ───────────────────────────────────
        _drawCurrentGameIndicators(dc, cx, h, m);
    }

    function _drawSetDots(dc as Graphics.Dc, cx as Number, y as Number,
                          setsG as Number, setsP as Number) as Void {
        // Up to 3 dots per side; ● filled = won, ○ empty = not yet
        var r      = 5;
        var gap    = 14;
        var maxSets = 3;
        // Our dots (left of center)
        for (var i = 0; i < maxSets; i++) {
            var filled = i < setsG;
            dc.setColor(filled ? Graphics.COLOR_WHITE : 0x444444,
                        Graphics.COLOR_TRANSPARENT);
            var x = cx - (maxSets - i) * gap;
            if (filled) { dc.fillCircle(x, y, r); }
            else        { dc.drawCircle(x, y, r); }
        }
        // Their dots (right of center)
        for (var i = 0; i < maxSets; i++) {
            var filled = i < setsP;
            dc.setColor(filled ? 0x888888 : 0x333333,
                        Graphics.COLOR_TRANSPARENT);
            var x = cx + (i + 1) * gap;
            if (filled) { dc.fillCircle(x, y, r); }
            else        { dc.drawCircle(x, y, r); }
        }
    }

    function _drawMetrics(dc as Graphics.Dc, cx as Number, h as Number,
                          m as MatchModel) as Void {
        var enfTotal = m.totalEnf();
        var enfPct   = m.enfPercentage();
        var sd       = m.serveWinData();
        var pctCon   = sd["pctConSaque"] as Number;
        var pctSin   = sd["pctSinSaque"] as Number;

        var y0  = h * 63 / 100;
        var col = 0x666666;
        var col2 = Graphics.COLOR_WHITE;
        var f   = Graphics.FONT_XTINY;
        var fx  = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // Two columns: left = ENF data, right = serve win data
        var lx = cx - cx / 2;
        var rx = cx + cx / 2;

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(lx, y0, f, "ENF", fx);
        dc.drawText(rx, y0, f, "%c/s", fx);

        dc.setColor(col2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(lx, y0 + 16, f, enfTotal.toString() + "  (" + enfPct + "%)", fx);
        dc.drawText(rx, y0 + 16, f, pctCon + "% / " + pctSin + "%", fx);
    }

    function _drawCurrentGameIndicators(dc as Graphics.Dc, cx as Number,
                                        h as Number, m as MatchModel) as Void {
        var y = h * 83 / 100;

        // Serve rectangle (blue pill, left side)
        if (m.currentGameSaque) {
            dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - 55, y - 9, 40, 18, 5);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - 35, y, Graphics.FONT_XTINY, "SQ",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ENF dots (orange, right side)
        var enf = m.currentGameEnf;
        var dotR = 5;
        var dotGap = 13;
        for (var i = 0; i < enf && i < 8; i++) {
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + 15 + i * dotGap, y, dotR);
        }
        // Overflow indicator if > 8
        if (enf > 8) {
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 15 + 8 * dotGap, y, Graphics.FONT_XTINY,
                "+" + (enf - 8).toString(),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}

// ─── DashboardDelegate ────────────────────────────────────────────────────────

class DashboardDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // LIGHT (top-left): toggle serve
    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_LIGHT
            && evt.getType() == WatchUi.KEY_PRESSED) {
            _handleSaque();
            return true;
        }
        // DOWN (bottom-left via next page in some layouts): undo
        if (evt.getKey() == WatchUi.KEY_DOWN
            && evt.getType() == WatchUi.KEY_PRESSED) {
            _handleUndo();
            return true;
        }
        return false;
    }

    // UP (middle-left): ENF
    function onPreviousPage() as Boolean {
        _handleEnf();
        return true;
    }

    // START (top-right): juego ganado
    function onSelect() as Boolean {
        _handleResult(RESULT_GANADO);
        return true;
    }

    // Long START: open edit menu
    function onHold(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) {
            WatchUi.pushView(new EditMenuView(), new EditMenuDelegate(),
                             WatchUi.SLIDE_UP);
            return true;
        }
        return false;
    }

    // BACK/LAP (bottom-right): juego perdido
    function onBack() as Boolean {
        _handleResult(RESULT_PERDIDO);
        return true;
    }

    // ── Private ──────────────────────────────────────────────────────────────

    function _vibrate() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 150)]);
        }
    }

    function _handleEnf() as Void {
        _vibrate();
        var fb = getModel().registerEnf();
        _showFeedback(fb);
    }

    function _handleSaque() as Void {
        _vibrate();
        var fb = getModel().toggleSaque();
        _showFeedback(fb);
    }

    function _handleResult(resultado as Number) as Void {
        _vibrate();
        var fb = getModel().registerResult(resultado);
        _showFeedback(fb);

        if (fb["setCompleted"] as Boolean) {
            // After feedback auto-dismisses, SetSummaryView will be pushed.
            // We pass it via the FeedbackView so timing stays clean.
        }
    }

    function _handleUndo() as Void {
        _vibrate();
        var fb = getModel().undo();
        _showFeedback(fb);
    }

    function _showFeedback(fbData as Dictionary) as Void {
        WatchUi.pushView(
            new FeedbackView(fbData),
            new FeedbackDelegate(fbData),
            WatchUi.SLIDE_IMMEDIATE
        );
    }
}
