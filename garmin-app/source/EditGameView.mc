import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// ─── EditGameView ─────────────────────────────────────────────────────────────
// Edits the last closed game: resultado, saque, ENF.
// Three fields cycle with UP/DOWN; START toggles the active field's value.
// BACK saves and exits.
//
// Only the most recent game is editable here — deeper edits are for the mobile app.

class EditGameView extends WatchUi.View {

    // Which field has focus: 0=resultado, 1=saque, 2=enf
    var _field   as Number = 0;
    var _result  as Number;
    var _saque   as Boolean;
    var _enf     as Number;
    var _gameIdx as Number; // index in model.games array

    function initialize() {
        View.initialize();
        var m = getModel();
        if (m.games.size() == 0) {
            // No game to edit — just return
            _gameIdx = -1;
            _result  = RESULT_GANADO;
            _saque   = false;
            _enf     = 0;
            return;
        }
        _gameIdx = m.games.size() - 1;
        var gd   = m.games[_gameIdx] as Dictionary;
        _result  = gd["res"] as Number;
        _saque   = (gd["saque"] as Number) == 1;
        _enf     = gd["enf"] as Number;
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_gameIdx < 0) {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_SMALL,
                "Sin juego previo",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var m  = getModel();
        var gd = m.games[_gameIdx] as Dictionary;
        var setNum  = gd["set"] as Number;
        var gameNum = gd["game"] as Number;

        // Title
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 10, Graphics.FONT_XTINY,
            "Juego " + gameNum + " · Set " + setNum,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Three rows
        _drawField(dc, cx, h * 30 / 100, "Resultado",
            _result == RESULT_GANADO ? "Ganado" : "Perdido",
            _field == 0);
        _drawField(dc, cx, h * 50 / 100, "Saque",
            _saque ? "Sí" : "No",
            _field == 1);
        _drawField(dc, cx, h * 70 / 100, "ENF",
            _enf.toString(),
            _field == 2);

        // Hint
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 88 / 100, Graphics.FONT_XTINY,
            "UP/DOWN campo · START editar · BACK guardar",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _drawField(dc as Graphics.Dc, cx as Number, y as Number,
                        label as String, value as String, selected as Boolean) as Void {
        if (selected) {
            dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(cx, y - 10, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (selected) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(cx, y + 10, Graphics.FONT_SMALL, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function moveFocus(delta as Number) as Void {
        _field = (_field + delta + 3) % 3;
        WatchUi.requestUpdate();
    }

    function toggleCurrentField() as Void {
        if (_field == 0) {
            _result = (_result == RESULT_GANADO) ? RESULT_PERDIDO : RESULT_GANADO;
        } else if (_field == 1) {
            _saque = !_saque;
        } else if (_field == 2) {
            _enf = (_enf + 1) % 10; // cycle 0–9
        }
        WatchUi.requestUpdate();
    }

    function save() as Void {
        if (_gameIdx < 0) { return; }
        var m  = getModel();
        var gd = m.games[_gameIdx] as Dictionary;
        gd["res"]   = _result;
        gd["saque"] = _saque ? 1 : 0;
        gd["enf"]   = _enf;
        m.games[_gameIdx] = gd;
    }
}

// ─── EditGameDelegate ─────────────────────────────────────────────────────────

class EditGameDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onPreviousPage() as Boolean {
        (_view() as EditGameView).moveFocus(-1);
        return true;
    }

    function onNextPage() as Boolean {
        (_view() as EditGameView).moveFocus(1);
        return true;
    }

    function onSelect() as Boolean {
        (_view() as EditGameView).toggleCurrentField();
        return true;
    }

    function onBack() as Boolean {
        (_view() as EditGameView).save();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function _view() as WatchUi.View {
        return WatchUi.getCurrentView()[0] as WatchUi.View;
    }
}
