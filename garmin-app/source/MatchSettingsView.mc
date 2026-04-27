import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// ─── MatchSettingsView ────────────────────────────────────────────────────────
// Three settings: tie-break (toggle), punto de oro (toggle), juegos por set (4/6/8).
// Native Menu2 with CheckboxMenuItem and MenuItem.

class MatchSettingsView extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({ :title => "Ajustes" });

        var m = getModel();

        addItem(new WatchUi.CheckboxMenuItem(
            "Tie-break", null, :tieBreak, m.tieBreakEnabled, {}));

        addItem(new WatchUi.CheckboxMenuItem(
            "Punto de oro", null, :puntoDeOro, m.puntoDeOro, {}));

        addItem(new WatchUi.MenuItem(
            "Juegos por set",
            m.juegosPorSet.toString(),
            :juegosPorSet, {}));
    }
}

// ─── MatchSettingsDelegate ────────────────────────────────────────────────────

class MatchSettingsDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var m  = getModel();
        var id = item.getId();

        if (id == :tieBreak) {
            m.tieBreakEnabled = !(item as WatchUi.CheckboxMenuItem).isChecked();
            (item as WatchUi.CheckboxMenuItem).setChecked(m.tieBreakEnabled);

        } else if (id == :puntoDeOro) {
            m.puntoDeOro = !(item as WatchUi.CheckboxMenuItem).isChecked();
            (item as WatchUi.CheckboxMenuItem).setChecked(m.puntoDeOro);

        } else if (id == :juegosPorSet) {
            // Cycle: 4 → 6 → 8 → 4
            var opts = [4, 6, 8] as Array<Number>;
            var cur  = m.juegosPorSet;
            var next = 6;
            for (var i = 0; i < opts.size(); i++) {
                if (opts[i] == cur) {
                    next = opts[(i + 1) % opts.size()];
                    break;
                }
            }
            m.juegosPorSet = next;
            item.setSubLabel(next.toString());
            WatchUi.requestUpdate();
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
