import QtQuick
import "../.." as Harness

// Faux AppModel : les jeux de démo, avec les rôles du vrai (name, running, appid,
// boxart). Les sessions créées sont factices : on en déclenche les signaux à la main.
ListModel {
    property var demo: Harness.DemoGames {}
    property int runningAppId: 0
    property var lastSession: null
    property Component session: Component {
        QtObject {
            signal stageStarting(string stage)
            signal connectionStarted()
            signal sessionFinished(int portTestResult)
        }
    }

    function initialize(manager, computerIndex, showHidden) {
        for (var i = 0; i < demo.count; i++)
            append({ name: demo.get(i).name, running: false, appid: 100 + i, boxart: demo.get(i).boxart })
    }
    function getDirectLaunchAppIndex() { return -1 }
    function getRunningAppId() { return runningAppId }
    function getRunningAppName() { return "" }
    function createSessionForApp(index) {
        lastSession = session.createObject(null)
        return lastSession
    }
    function quitRunningApp() {}
}
