import Toybox.Application;
import Toybox.Lang;

// Wraps Application.Storage for match history.
// Keeps the last 10 match summaries as an Array of Dictionaries.

class StorageModel {

    static const MAX_HISTORY = 10;
    static const KEY_HISTORY = "matchHistory";

    // Returns Array<Dictionary> — most recent first
    static function loadHistory() as Array {
        var stored = Application.Storage.getValue(KEY_HISTORY);
        if (stored == null) {
            return [] as Array<Dictionary>;
        }
        return stored as Array;
    }

    // Prepends a summary dict and trims to MAX_HISTORY entries
    static function saveMatch(summaryDict as Dictionary) as Void {
        var history = loadHistory();
        history.addAll([summaryDict]); // add at end temporarily
        // Rotate: keep latest MAX_HISTORY
        var result = [] as Array<Dictionary>;
        var start = history.size() > MAX_HISTORY
            ? history.size() - MAX_HISTORY
            : 0;
        for (var i = history.size() - 1; i >= start; i--) {
            result.add(history[i]);
        }
        Application.Storage.setValue(KEY_HISTORY, result);
    }

    // % de victorias histórico (0-100 integer)
    static function historicWinPct() as Number {
        var history = loadHistory();
        if (history.size() == 0) { return 0; }
        var wins = 0;
        for (var i = 0; i < history.size(); i++) {
            var d = history[i] as Dictionary;
            if ((d["resultado"] as Number) == RESULT_GANADO) { wins++; }
        }
        return wins * 100 / history.size();
    }

    // Current streak: positive = wins, negative = losses, 0 = none
    static function currentStreak() as Number {
        var history = loadHistory();
        if (history.size() == 0) { return 0; }
        var first = (history[0] as Dictionary)["resultado"] as Number;
        var count = 0;
        for (var i = 0; i < history.size(); i++) {
            var res = (history[i] as Dictionary)["resultado"] as Number;
            if (res == first) {
                count++;
            } else {
                break;
            }
        }
        return first == RESULT_GANADO ? count : -count;
    }

    // Array of last MAX_HISTORY ENF-per-game values (float as * 10 integer)
    static function enfHistory() as Array {
        var history = loadHistory();
        var result = [] as Array<Number>;
        // history is most-recent-first; we want chronological for the graph
        for (var i = history.size() - 1; i >= 0; i--) {
            var d = history[i] as Dictionary;
            var g = d["totalGames"] as Number;
            var e = d["totalEnf"] as Number;
            result.add(g > 0 ? (e * 10 / g) : 0); // ENF/game * 10 for integer math
        }
        return result;
    }
}
