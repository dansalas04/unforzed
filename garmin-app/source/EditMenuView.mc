import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// ─── EditMenuView ─────────────────────────────────────────────────────────────
// 5-option menu accessed via long press on START.
// Uses native Menu2 for clean, scroll-friendly rendering.

class EditMenuView extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({ :title => "Edición" });

        addItem(new WatchUi.MenuItem(
            "Editar juego anterior", null, :editGame, {}));
        addItem(new WatchUi.MenuItem(
            "Cambiar posición", null, :changePosition, {}));
        addItem(new WatchUi.MenuItem(
            "Editar marcador", null, :editScore, {}));
        addItem(new WatchUi.MenuItem(
            "Ajustes del partido", null, :matchSettings, {}));
        addItem(new WatchUi.MenuItem(
            "Terminar partido", null, :endMatch, {}));
    }
}

// ─── EditMenuDelegate ─────────────────────────────────────────────────────────

class EditMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :editGame) {
            WatchUi.pushView(new EditGameView(), new EditGameDelegate(),
                             WatchUi.SLIDE_LEFT);

        } else if (id == :changePosition) {
            // Toggle immediately, return to dashboard
            var m = getModel();
            m.posicion = (m.posicion == POS_DRIVE) ? POS_REVES : POS_DRIVE;
            WatchUi.popView(WatchUi.SLIDE_DOWN); // dismiss menu
            WatchUi.requestUpdate();

        } else if (id == :editScore) {
            WatchUi.pushView(new EditScoreView(:juegosG),
                             new EditScoreDelegate(),
                             WatchUi.SLIDE_LEFT);

        } else if (id == :matchSettings) {
            WatchUi.pushView(new MatchSettingsView(),
                             new MatchSettingsDelegate(),
                             WatchUi.SLIDE_LEFT);

        } else if (id == :endMatch) {
            WatchUi.pushView(new EndMatchView(), new EndMatchDelegate(),
                             WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
