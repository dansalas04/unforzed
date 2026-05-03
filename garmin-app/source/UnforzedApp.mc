import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;

class UnforzedApp extends Application.AppBase {

    var model as MatchModel;

    function initialize() {
        AppBase.initialize();
        model = new MatchModel();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Initial view: position-selection step of the setup wizard
    function getInitialView() {
        var view = new SetupView(:position);
        var delegate = new SetupDelegate(view);
        return [view, delegate];
    }
}

// Convenience accessor used by all views
function getModel() as MatchModel {
    return (Application.getApp() as UnforzedApp).model;
}
