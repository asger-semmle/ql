import javascript

module Firebase {
  
  /** Gets a reference to the firebase API object. */
  private DataFlow::SourceNode firebase(DataFlow::TrackSummary t) {
    result = DataFlow::moduleImport("firebase/app") and t.start()
    or
    result = DataFlow::globalVarRef("firebase") and t.start()
    or
    exists (DataFlow::TrackSummary t2 |
      result = firebase(t2).track(t2, t)
    )
  }

  /** Gets a reference to the firebase API object. */
  DataFlow::SourceNode firebase() {
    result = firebase(_)
  }

  /** Gets a reference to a firebase app created with `initializeApp`. */
  private DataFlow::SourceNode initApp(DataFlow::TrackSummary t) {
    result = firebase().getAMethodCall("initializeApp") and t.start()
    or
    exists (DataFlow::TrackSummary t2 |
      result = initApp(t2).track(t2, t)
    )
  }

  /**
   * Gets a reference to a firebase app, either the `firebase` object or an
   * app created explicitly with `initializeApp()`.
   */
  DataFlow::SourceNode app() {
    result = firebase(_) or result = initApp(_)
  }

  /** Gets a reference to a firebase database object, such as `firebase.database()`. */
  private DataFlow::SourceNode database(DataFlow::TrackSummary t) {
    result = app().getAMethodCall("database") and t.start()
    or
    exists (DataFlow::TrackSummary t2 |
      result = database(t2).track(t2, t)
    )
  }

  /** Gets a reference to a firebase database object, such as `firebase.database()`. */
  DataFlow::SourceNode database() {
    result = database(_)
  }

  /** Gets a call to `ref` or `refFromURL` on a firebase database. */
  DataFlow::SourceNode ref(DataFlow::TrackSummary t) {
    t.start() and
    exists (string name | result = database().getAMethodCall(name) |
      name = "ref" or
      name = "refFromURL"
    )
    or
    t.start() and
    exists (string name | result = ref(_).getAMethodCall(name) |
      name = "push" or
      name = "child"
    )
    or
    exists (DataFlow::TrackSummary t2 |
      result = ref(t2).track(t2, t)
    )
  }
  
  DataFlow::SourceNode ref() {
    result = ref(_)
  }

  DataFlow::SourceNode snapshot(DataFlow::TrackSummary t) {
    t.start() and
    exists (DataFlow::MethodCallNode call |
      call = ref().getAMethodCall() and
      (call.getMethodName() = "on" or call.getMethodName() = "once") and
      call.getArgument(0).asExpr().getStringValue() = "value" and
      (
        result = call // returns promise
        or
        result = call.getCallback(1).getParameter(0)
      )
    )
    or
    promiseTaintStep(snapshot(t), result)
    or
    exists (DataFlow::TrackSummary t2 |
      result = ref(t2).track(t2, t)
    )
  }

  DataFlow::SourceNode snapshot() {
    result = snapshot(_)
  }
  
  class FirebaseVal extends RemoteFlowSource {
    FirebaseVal() {
      this = snapshot().getAMethodCall("val")
    }

    override string getSourceType() {
      result = "Firebase database"
    }
  }
}
