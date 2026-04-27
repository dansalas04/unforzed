import Toybox.Lang;
import Toybox.Time;

// ─── Constants ────────────────────────────────────────────────────────────────

// Results
const RESULT_GANADO  = 0;
const RESULT_PERDIDO = 1;

// Position
const POS_DRIVE = 0;
const POS_REVES = 1;

// Event types in the LIFO undo stack
const EVT_ENF          = 0; // added one ENF to current game
const EVT_SAQUE_TOGGLE = 1; // toggled serve for current game
const EVT_RESULT       = 2; // closed a game with a result

// Feedback variants
const FB_GANADO   = 0;
const FB_PERDIDO  = 1;
const FB_ENF      = 2;
const FB_SAQUE    = 3;
const FB_DESHACER = 4;

// Undo sub-type shown in feedback
const UNDO_ENF    = 0;
const UNDO_SAQUE  = 1;
const UNDO_JUEGO  = 2;
const UNDO_NADA   = 3;

// ─── MatchModel ───────────────────────────────────────────────────────────────
//
// Single source of truth for the entire match. No view logic here.
// Accessed via Application.getApp().model.
//
class MatchModel {

    // Settings (configured before/during match)
    var juegosPorSet   as Number = 6;
    var tieBreakEnabled as Boolean = true;
    var puntoDeOro     as Boolean = false;
    var posicion       as Number = POS_DRIVE; // POS_DRIVE | POS_REVES

    // Match-level tracking
    var setsGanados    as Number = 0;
    var setsPerdidos   as Number = 0;
    var currentSet     as Number = 1;

    // Current-set tracking
    var juegosGanadosEnSet  as Number = 0;
    var juegosPerdidosEnSet as Number = 0;

    // _firstServeOfSet: true = we serve the 1st game of the current set
    var _firstServeOfSet as Boolean = true;

    // Current-game tracking
    var currentGameNumInSet as Number = 1;
    var currentGameEnf      as Number = 0;
    var currentGameSaque    as Boolean = false; // live state (auto + user override)
    var currentGameIsTiebreak as Boolean = false;

    // Completed game/set records stored as Array of Dictionaries
    var games as Array = [] as Array<Dictionary>;
    var sets  as Array = [] as Array<Dictionary>;

    // Flat LIFO undo stack — events from ALL games coexist here
    // Each entry is a Dictionary with at minimum "type" key.
    var _eventStack as Array = [] as Array<Dictionary>;

    // Match timing
    var _startTime as Number = 0;

    // ─── Setup ───────────────────────────────────────────────────────────────

    // Called after setup wizard completes (step 1: position, step 2: who serves)
    function initMatch(pos as Number, weSacamerosPrimero as Boolean) as Void {
        posicion = pos;
        _startTime = Time.now().value();
        initNewSet(weSacamerosPrimero);
    }

    // Called at the start of each set (including set 1 via initMatch)
    function initNewSet(weServePrimero as Boolean) as Void {
        _firstServeOfSet    = weServePrimero;
        juegosGanadosEnSet  = 0;
        juegosPerdidosEnSet = 0;
        currentGameNumInSet = 1;
        _startNewGameState();
    }

    // Recomputes current-game state from scratch for game currentGameNumInSet
    function _startNewGameState() as Void {
        currentGameEnf       = 0;
        currentGameIsTiebreak = _isTiebreakGame();
        // Auto serve: odd games → same as first server of set; even games → opposite
        currentGameSaque = (currentGameNumInSet % 2 == 1)
            ? _firstServeOfSet
            : !_firstServeOfSet;
    }

    // True if the current game should be flagged as a tie-break
    function _isTiebreakGame() as Boolean {
        return tieBreakEnabled
            && juegosGanadosEnSet == juegosPorSet
            && juegosPerdidosEnSet == juegosPorSet;
    }

    // ─── Event handlers ──────────────────────────────────────────────────────

    // UP button: add one ENF.
    // Returns Dictionary with feedback data.
    function registerEnf() as Dictionary {
        currentGameEnf++;
        _eventStack.add({ "type" => EVT_ENF });
        return {
            "fb"         => FB_ENF,
            "enfCount"   => currentGameEnf,
            "gameNum"    => _totalGames() + 1
        };
    }

    // LIGHT button: toggle serve for current game.
    function toggleSaque() as Dictionary {
        currentGameSaque = !currentGameSaque;
        _eventStack.add({ "type" => EVT_SAQUE_TOGGLE });
        return {
            "fb"       => FB_SAQUE,
            "saque"    => currentGameSaque,
            "posicion" => posicion,
            "gameNum"  => _totalGames() + 1
        };
    }

    // START / BACK button: close current game with a result.
    // Returns Dictionary with feedback data + optional "setCompleted" key.
    function registerResult(resultado as Number) as Dictionary {
        var totalGamesBefore = _totalGames();
        var gameNum          = currentGameNumInSet;
        var setNum           = currentSet;
        var isTb             = currentGameIsTiebreak;
        var saque            = currentGameSaque;
        var enf              = currentGameEnf;

        // Build the game record
        var gameDict = {
            "set"     => setNum,
            "game"    => gameNum,
            "saque"   => saque ? 1 : 0,
            "enf"     => enf,
            "res"     => resultado,
            "tb"      => isTb ? 1 : 0,
            "ts"      => Time.now().value()
        };
        games.add(gameDict);

        // Update running score
        var prevGanados  = juegosGanadosEnSet;
        var prevPerdidos = juegosPerdidosEnSet;
        if (resultado == RESULT_GANADO) {
            juegosGanadosEnSet++;
        } else {
            juegosPerdidosEnSet++;
        }

        // Check if the set is over
        var setCompleted = _isSetOver();
        var setDict      = null;
        var prevSetsG    = setsGanados;
        var prevSetsP    = setsPerdidos;
        var prevSet      = currentSet;
        var prevFirstServe = _firstServeOfSet;

        if (setCompleted) {
            var setWon = (juegosGanadosEnSet > juegosPerdidosEnSet);
            if (setWon) { setsGanados++; } else { setsPerdidos++; }
            setDict = {
                "set"  => currentSet,
                "jg"   => juegosGanadosEnSet,
                "jp"   => juegosPerdidosEnSet,
                "tb"   => isTb ? 1 : 0
            };
            sets.add(setDict);
            currentSet++;
        }

        // Push to undo stack
        _eventStack.add({
            "type"        => EVT_RESULT,
            "gameDict"    => gameDict,
            "prevGanados" => prevGanados,
            "prevPerdidos"=> prevPerdidos,
            "setCompleted"=> setCompleted,
            "setDict"     => setDict,
            "prevSetsG"   => prevSetsG,
            "prevSetsP"   => prevSetsP,
            "prevSet"     => prevSet,
            "prevFirstServe" => prevFirstServe
        });

        // Advance to next game (unless set is over — caller handles new-set prompt)
        if (!setCompleted) {
            currentGameNumInSet++;
            _startNewGameState();
        }

        var fb = {
            "fb"        => resultado == RESULT_GANADO ? FB_GANADO : FB_PERDIDO,
            "gameNum"   => gameNum,
            "saque"     => saque,
            "enf"       => enf,
            "setCompleted" => setCompleted
        };
        if (setCompleted) {
            fb["setDict"]      = setDict;
            fb["setsGanados"]  = setsGanados;
            fb["setsPerdidos"] = setsPerdidos;
        }
        return fb;
    }

    // DOWN button: undo last event.
    // Returns Dictionary with feedback data.
    function undo() as Dictionary {
        if (_eventStack.size() == 0) {
            return { "fb" => FB_DESHACER, "undoType" => UNDO_NADA };
        }

        var last = _eventStack[_eventStack.size() - 1];
        _eventStack = _eventStack.slice(0, _eventStack.size() - 1);
        var evtType = last["type"] as Number;

        if (evtType == EVT_ENF) {
            currentGameEnf--;
            return { "fb" => FB_DESHACER, "undoType" => UNDO_ENF };
        }

        if (evtType == EVT_SAQUE_TOGGLE) {
            currentGameSaque = !currentGameSaque;
            return { "fb" => FB_DESHACER, "undoType" => UNDO_SAQUE };
        }

        if (evtType == EVT_RESULT) {
            // Reopen the last closed game
            var gameDict = last["gameDict"] as Dictionary;

            // Remove the game record
            games = games.slice(0, games.size() - 1);

            // Restore set state if a set was completed
            if (last["setCompleted"] as Boolean) {
                sets = sets.slice(0, sets.size() - 1);
                currentSet       = last["prevSet"] as Number;
                setsGanados      = last["prevSetsG"] as Number;
                setsPerdidos     = last["prevSetsP"] as Number;
                _firstServeOfSet = last["prevFirstServe"] as Boolean;
            }

            // Restore game-level scoring
            juegosGanadosEnSet  = last["prevGanados"] as Number;
            juegosPerdidosEnSet = last["prevPerdidos"] as Number;

            // Restore current game state from the game dict
            currentGameNumInSet   = gameDict["game"] as Number;
            currentGameEnf        = gameDict["enf"] as Number;
            currentGameSaque      = (gameDict["saque"] as Number) == 1;
            currentGameIsTiebreak = (gameDict["tb"] as Number) == 1;
            // Note: the events that built this game's ENF/SAQUE state
            // are already sitting below on the _eventStack — fully undoable.

            return { "fb" => FB_DESHACER, "undoType" => UNDO_JUEGO };
        }

        return { "fb" => FB_DESHACER, "undoType" => UNDO_NADA };
    }

    // ─── Set completion logic ─────────────────────────────────────────────────

    function _isSetOver() as Boolean {
        var g = juegosGanadosEnSet;
        var p = juegosPerdidosEnSet;
        var n = juegosPorSet;

        // Tie-break just played (one side reaches n+1)
        if (tieBreakEnabled && (g == n + 1 || p == n + 1)) {
            return true;
        }
        // Normal win: reach n with 2-game lead (covers 6-4, 7-5 style)
        if (g >= n && g - p >= 2) { return true; }
        if (p >= n && p - g >= 2) { return true; }
        return false;
    }

    // True when the next game to play is a tie-break trigger game
    // (used by caller to know whether to flag next game as tiebreak)
    function isTiebreakPending() as Boolean {
        return tieBreakEnabled
            && juegosGanadosEnSet == juegosPorSet
            && juegosPerdidosEnSet == juegosPorSet;
    }

    // ─── Stats helpers ───────────────────────────────────────────────────────

    function _totalGames() as Number {
        return games.size();
    }

    function totalEnf() as Number {
        var total = 0;
        for (var i = 0; i < games.size(); i++) {
            total += (games[i])["enf"] as Number;
        }
        return total;
    }

    function enfPercentage() as Number {
        // ENF / juegos * 100, integer
        var g = games.size();
        if (g == 0) { return 0; }
        return (totalEnf() * 100 / g);
    }

    // Games won with serve / total games with serve
    function serveWinData() as Dictionary {
        var conSaque = 0;
        var ganadosConSaque = 0;
        var sinSaque = 0;
        var ganadosSinSaque = 0;
        for (var i = 0; i < games.size(); i++) {
            var gd = games[i] as Dictionary;
            var hasSaque = (gd["saque"] as Number) == 1;
            var won = (gd["res"] as Number) == RESULT_GANADO;
            if (hasSaque) {
                conSaque++;
                if (won) { ganadosConSaque++; }
            } else {
                sinSaque++;
                if (won) { ganadosSinSaque++; }
            }
        }
        return {
            "conSaque"         => conSaque,
            "ganadosConSaque"  => ganadosConSaque,
            "sinSaque"         => sinSaque,
            "ganadosSinSaque"  => ganadosSinSaque,
            "pctConSaque"      => conSaque > 0 ? (ganadosConSaque * 100 / conSaque) : 0,
            "pctSinSaque"      => sinSaque > 0 ? (ganadosSinSaque * 100 / sinSaque) : 0
        };
    }

    // ENF stats for a specific set number
    function enfForSet(setNum as Number) as Number {
        var total = 0;
        for (var i = 0; i < games.size(); i++) {
            var gd = games[i] as Dictionary;
            if ((gd["set"] as Number) == setNum) {
                total += gd["enf"] as Number;
            }
        }
        return total;
    }

    // Duration in seconds since match start
    function elapsedSeconds() as Number {
        return (Time.now().value() - _startTime).toNumber();
    }

    // Set with fewest ENF (for final summary)
    function bestSetByEnf() as Number {
        if (sets.size() == 0) { return 1; }
        var best = 1;
        var bestEnf = 9999;
        for (var i = 0; i < sets.size(); i++) {
            var s = (sets[i])["set"] as Number;
            var e = enfForSet(s);
            if (e < bestEnf) { bestEnf = e; best = s; }
        }
        return best;
    }

    // Match result: did we win the match? (best of 3 sets)
    function matchResult() as Number {
        return (setsGanados > setsPerdidos) ? RESULT_GANADO : RESULT_PERDIDO;
    }

    // ─── Manual score edit (from EditScoreView) ───────────────────────────────

    function editScore(juegosG as Number, juegosP as Number,
                       setsG as Number, setsP as Number) as Void {
        juegosGanadosEnSet  = juegosG;
        juegosPerdidosEnSet = juegosP;
        setsGanados         = setsG;
        setsPerdidos        = setsP;
        // Recompute tie-break flag for next game
        currentGameIsTiebreak = _isTiebreakGame();
    }

    // ─── Serialization for storage ────────────────────────────────────────────

    function toSummaryDict() as Dictionary {
        var sd = serveWinData();
        return {
            "ts"        => _startTime,
            "duration"  => elapsedSeconds(),
            "setsG"     => setsGanados,
            "setsP"     => setsPerdidos,
            "totalGames"=> games.size(),
            "totalEnf"  => totalEnf(),
            "pctConSaque"   => sd["pctConSaque"],
            "pctSinSaque"   => sd["pctSinSaque"],
            "resultado" => matchResult()
        };
    }
}
