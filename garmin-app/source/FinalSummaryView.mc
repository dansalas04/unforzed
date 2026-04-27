import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;

// ─── FinalSummaryView ─────────────────────────────────────────────────────────
// 4 pages navigated with UP/DOWN.
//   P1: Resultado (win/lose, sets, duration, total games)
//   P2: Saque (win% con/sin serve, game counts)
//   P3: ENF (total, %, desglose por set, mejor set)
//   P4: Histórico (ENF trend sparkline, win%, racha)
//
// At page 4: START saves and exits the activity.
// No auto-dismiss — user controls when to close.

class FinalSummaryView extends WatchUi.View {

    var _page    as Number = 0; // 0-3
    var _model   as MatchModel;
    var _history as Array;

    function initialize() {
        View.initialize();
        _model   = getModel();
        _history = StorageModel.loadHistory();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Page indicator (top-right corner)
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 4, 4, Graphics.FONT_XTINY,
            (_page + 1).toString() + "/4",
            Graphics.TEXT_JUSTIFY_RIGHT);

        switch (_page) {
            case 0: _drawPage1(dc, cx, w, h); break;
            case 1: _drawPage2(dc, cx, w, h); break;
            case 2: _drawPage3(dc, cx, w, h); break;
            case 3: _drawPage4(dc, cx, w, h); break;
        }
    }

    // ── Page 1: Resultado ────────────────────────────────────────────────────

    function _drawPage1(dc as Graphics.Dc, cx as Number, w as Number, h as Number) as Void {
        var m   = _model;
        var won = m.matchResult() == RESULT_GANADO;

        // Win / lose banner
        dc.setColor(won ? 0x00CC44 : 0xCC2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 20 / 100, Graphics.FONT_LARGE,
            won ? "GANADO" : "PERDIDO",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Sets score
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 38 / 100, Graphics.FONT_NUMBER_HOT,
            m.setsGanados.toString() + "-" + m.setsPerdidos.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 50 / 100, Graphics.FONT_XTINY, "sets",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Duration and game count
        var secs = m.elapsedSeconds();
        var mins = secs / 60;
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 63 / 100, Graphics.FONT_SMALL,
            mins.toString() + " min",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.drawText(cx, h * 76 / 100, Graphics.FONT_XTINY,
            m.games.size().toString() + " juegos",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Start prompt on page 4; on p1 just navigation hint
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 90 / 100, Graphics.FONT_XTINY, "DOWN →",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── Page 2: Saque ─────────────────────────────────────────────────────────

    function _drawPage2(dc as Graphics.Dc, cx as Number, w as Number, h as Number) as Void {
        var sd = _model.serveWinData();
        var pctCon = sd["pctConSaque"] as Number;
        var pctSin = sd["pctSinSaque"] as Number;
        var conTotal = sd["conSaque"] as Number;
        var sinTotal = sd["sinSaque"] as Number;
        var gCon  = sd["ganadosConSaque"] as Number;
        var gSin  = sd["ganadosSinSaque"] as Number;
        var diff  = pctCon - pctSin;

        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 12 / 100, Graphics.FONT_SMALL, "SAQUE",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        _drawStatRow(dc, cx, h * 27 / 100, "Con saque",
            pctCon.toString() + "%  (" + gCon + "/" + conTotal + ")");
        _drawStatRow(dc, cx, h * 43 / 100, "Sin saque",
            pctSin.toString() + "%  (" + gSin + "/" + sinTotal + ")");

        // Divider
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 50, h * 54 / 100, cx + 50, h * 54 / 100);

        // Difference
        var diffStr = (diff >= 0 ? "+" : "") + diff.toString() + " pp con saque";
        dc.setColor(diff >= 0 ? 0x00CC44 : 0xCC2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 63 / 100, Graphics.FONT_XTINY, diffStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── Page 3: ENF ───────────────────────────────────────────────────────────

    function _drawPage3(dc as Graphics.Dc, cx as Number, w as Number, h as Number) as Void {
        var m        = _model;
        var enfTotal = m.totalEnf();
        var enfPct   = m.enfPercentage();
        var bestSet  = m.bestSetByEnf();

        dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 12 / 100, Graphics.FONT_SMALL, "ENF",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        _drawStatRow(dc, cx, h * 27 / 100, "Totales", enfTotal.toString());
        _drawStatRow(dc, cx, h * 40 / 100, "ENF / juego",
            (enfPct / 10).toString() + "." + (enfPct % 10).toString());

        // By set
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 53 / 100, Graphics.FONT_XTINY, "Por set",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var y = h * 63 / 100;
        for (var i = 0; i < m.sets.size() && i < 3; i++) {
            var sd    = m.sets[i] as Dictionary;
            var sn    = sd["set"] as Number;
            var enfSt = m.enfForSet(sn);
            var star  = (sn == bestSet) ? " ★" : "";
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY,
                "Set " + sn + ": " + enfSt + " ENF" + star,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            y += 16;
        }
        // If current set not closed yet
        var curEnf = m.enfForSet(m.currentSet) + m.currentGameEnf;
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY,
            "Set " + m.currentSet + ": " + curEnf + " ENF (parcial)",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── Page 4: Histórico ─────────────────────────────────────────────────────

    function _drawPage4(dc as Graphics.Dc, cx as Number, w as Number, h as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 10 / 100, Graphics.FONT_SMALL, "HISTÓRICO",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Sparkline ENF/game for last 10 matches
        _drawSparkline(dc, cx, w, h);

        // Win % and streak from storage
        var winPct = StorageModel.historicWinPct();
        var streak = StorageModel.currentStreak();
        var streakStr = streak >= 0
            ? (streak.toString() + " victorias")
            : ((-streak).toString() + " derrotas");

        _drawStatRow(dc, cx, h * 72 / 100, "% victorias", winPct.toString() + "%");
        _drawStatRow(dc, cx, h * 84 / 100, "Racha", streakStr);

        // Save prompt
        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 94 / 100, Graphics.FONT_XTINY, "START = guardar y cerrar",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawSparkline(dc as Graphics.Dc, cx as Number, w as Number, h as Number) as Void {
        var data = StorageModel.enfHistory(); // array of ENF/game * 10
        // Append current match
        var m = _model;
        var g = m.games.size();
        data.add(g > 0 ? (m.totalEnf() * 10 / g) : 0);

        var count = data.size();
        if (count < 2) { return; }

        var chartW = w * 70 / 100;
        var chartH = h * 18 / 100;
        var x0     = cx - chartW / 2;
        var y0     = h * 55 / 100;

        // Find min/max
        var maxV = 1;
        for (var i = 0; i < count; i++) {
            var v = data[i] as Number;
            if (v > maxV) { maxV = v; }
        }

        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x0, y0, chartW, chartH);

        // Draw line segments
        for (var i = 1; i < count; i++) {
            var x1 = x0 + (i - 1) * chartW / (count - 1);
            var x2 = x0 + i * chartW / (count - 1);
            var y1 = y0 + chartH - (data[i - 1] as Number) * chartH / maxV;
            var y2 = y0 + chartH - (data[i] as Number) * chartH / maxV;
            dc.setColor(i == count - 1 ? 0xFF8800 : 0x666666,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x1, y1, x2, y2);
        }

        // Highlight current point
        var lastX = x0 + chartW - 1;
        var lastY = y0 + chartH - (data[count - 1] as Number) * chartH / maxV;
        dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lastX, lastY, 4);
    }

    // ── Common helpers ───────────────────────────────────────────────────────

    function _drawStatRow(dc as Graphics.Dc, cx as Number, y as Number,
                          label as String, value as String) as Void {
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y - 8, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y + 8, Graphics.FONT_SMALL, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── Navigation ───────────────────────────────────────────────────────────

    function nextPage() as Void {
        if (_page < 3) { _page++; WatchUi.requestUpdate(); }
    }

    function prevPage() as Void {
        if (_page > 0) { _page--; WatchUi.requestUpdate(); }
    }
}

// ─── FinalSummaryDelegate ─────────────────────────────────────────────────────

class FinalSummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // DOWN = next page
    function onNextPage() as Boolean {
        var view = _view() as FinalSummaryView;
        view.nextPage();
        return true;
    }

    // UP = previous page
    function onPreviousPage() as Boolean {
        var view = _view() as FinalSummaryView;
        view.prevPage();
        return true;
    }

    // START on page 4 = save and exit; on other pages = no-op
    function onSelect() as Boolean {
        var view = _view() as FinalSummaryView;
        if (view._page == 3) {
            // Activity already saved in EndMatchView or SetSummaryView path.
            // Exit the app.
            System.exit();
        }
        return true;
    }

    // BACK does nothing (user must use START to close)
    function onBack() as Boolean {
        return true;
    }

    function _view() as WatchUi.View {
        return WatchUi.getCurrentView()[0] as WatchUi.View;
    }
}
