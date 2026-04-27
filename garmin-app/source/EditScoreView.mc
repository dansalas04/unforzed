import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// ─── EditScoreView ────────────────────────────────────────────────────────────
// Sequential single-field editor: one screen per value.
// Fields in order: juegosG → juegosP → setsG → setsP
// UP/DOWN change value; START advances to next field; BACK goes back one field.

class EditScoreView extends WatchUi.View {

    // Field identifiers
    static const FIELD_JUEGOS_G = 0;
    static const FIELD_JUEGOS_P = 1;
    static const FIELD_SETS_G   = 2;
    static const FIELD_SETS_P   = 3;

    var _field    as Number;
    var _juegosG  as Number;
    var _juegosP  as Number;
    var _setsG    as Number;
    var _setsP    as Number;

    function initialize(startField as Symbol) {
        View.initialize();
        var m = getModel();
        _juegosG = m.juegosGanadosEnSet;
        _juegosP = m.juegosPerdidosEnSet;
        _setsG   = m.setsGanados;
        _setsP   = m.setsPerdidos;
        _field   = FIELD_JUEGOS_G;
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var label = _fieldLabel();
        var value = _currentValue();
        var max   = _maxValue();

        // Field label
        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 25 / 100, Graphics.FONT_SMALL, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Big number
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2, Graphics.FONT_NUMBER_HOT, value.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // UP/DOWN arrows hint
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 72 / 100, Graphics.FONT_XTINY,
            "▲ / ▼   START=siguiente",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Progress indicator
        dc.drawText(cx, h * 85 / 100, Graphics.FONT_XTINY,
            (_field + 1).toString() + " / 4",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function _fieldLabel() as String {
        switch (_field) {
            case FIELD_JUEGOS_G: return "Juegos nuestros";
            case FIELD_JUEGOS_P: return "Juegos ellos";
            case FIELD_SETS_G:   return "Sets nuestros";
            case FIELD_SETS_P:   return "Sets ellos";
        }
        return "";
    }

    function _currentValue() as Number {
        switch (_field) {
            case FIELD_JUEGOS_G: return _juegosG;
            case FIELD_JUEGOS_P: return _juegosP;
            case FIELD_SETS_G:   return _setsG;
            case FIELD_SETS_P:   return _setsP;
        }
        return 0;
    }

    function _maxValue() as Number {
        switch (_field) {
            case FIELD_JUEGOS_G:
            case FIELD_JUEGOS_P: return getModel().juegosPorSet + 1;
            case FIELD_SETS_G:
            case FIELD_SETS_P:   return 2;
        }
        return 9;
    }

    function changeValue(delta as Number) as Void {
        var max = _maxValue();
        switch (_field) {
            case FIELD_JUEGOS_G:
                _juegosG = (_juegosG + delta + max + 1) % (max + 1); break;
            case FIELD_JUEGOS_P:
                _juegosP = (_juegosP + delta + max + 1) % (max + 1); break;
            case FIELD_SETS_G:
                _setsG = (_setsG + delta + max + 1) % (max + 1); break;
            case FIELD_SETS_P:
                _setsP = (_setsP + delta + max + 1) % (max + 1); break;
        }
        WatchUi.requestUpdate();
    }

    // Returns true if this was the last field (caller should pop)
    function advance() as Boolean {
        if (_field == FIELD_SETS_P) {
            _applyToModel();
            return true;
        }
        _field++;
        WatchUi.requestUpdate();
        return false;
    }

    function goBack() as Boolean {
        if (_field == FIELD_JUEGOS_G) {
            return true; // nothing behind us
        }
        _field--;
        WatchUi.requestUpdate();
        return false;
    }

    function _applyToModel() as Void {
        getModel().editScore(_juegosG, _juegosP, _setsG, _setsP);
    }
}

// ─── EditScoreDelegate ────────────────────────────────────────────────────────

class EditScoreDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onPreviousPage() as Boolean {
        (_view() as EditScoreView).changeValue(1);
        return true;
    }

    function onNextPage() as Boolean {
        (_view() as EditScoreView).changeValue(-1);
        return true;
    }

    function onSelect() as Boolean {
        var done = (_view() as EditScoreView).advance();
        if (done) { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
        return true;
    }

    function onBack() as Boolean {
        var first = (_view() as EditScoreView).goBack();
        if (first) { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
        return true;
    }

    function _view() as WatchUi.View {
        return WatchUi.getCurrentView()[0] as WatchUi.View;
    }
}
