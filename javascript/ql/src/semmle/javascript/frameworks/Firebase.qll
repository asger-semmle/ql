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
  DataFlow::SourceNode refSource() {
    exists (string name | result = database().getAMethodCall(name) |
      name = "ref" or
      name = "refFromURL"
    )
  }
  
  private predicate hasFirebaseTaintSource() {
    exists(refSource())
  }

  private class FirebaseRefSource extends DataFlow::AdditionalSource {
    FirebaseRefSource() {
      this = refSource()
    }

    override predicate isSourceFor(DataFlow::Configuration config, DataFlow::FlowLabel label) {
      label = "firebase-ref"
    }
  }
  
  /**
   * Label representing a Firebase reference or a "value" event response from such a reference.
   */
  class FirebaseRefLabel extends DataFlow::FlowLabel {
    FirebaseRefLabel() {
      hasFirebaseTaintSource() and
      this = "firebase-ref"
    }
  }

  /**
   * A step `ref -> ref.val()`, transforming a firebase ref to a tainted value.
   */
  class ValStep extends DataFlow::AdditionalFlowStep, DataFlow::MethodCallNode {
    ValStep() {
      hasFirebaseTaintSource() and
      getMethodName() = "val" and
      getNumArgument() = 0
    }
  
    override predicate step(
      DataFlow::Node pred, DataFlow::Node succ, DataFlow::FlowLabel predlbl,
      DataFlow::FlowLabel succlbl
    ) {
      predlbl = "firebase-ref" and
      succlbl = DataFlow::FlowLabel::taint() and
      pred = getReceiver() and
      succ = this
    }
  }

  /**
   * A step `ref -> ref.child()` or `ref -> ref.push()`, returning a new firebase ref.
   */
  class RefChildStep extends DataFlow::AdditionalFlowStep, DataFlow::MethodCallNode {
    RefChildStep() {
      hasFirebaseTaintSource() and
      exists (string name | name = getMethodName() |
        name = "child" and
        getNumArgument() = 1
        or
        name = "push" and
        getNumArgument() = 0
      )
    }
  
    override predicate step(
      DataFlow::Node pred, DataFlow::Node succ, DataFlow::FlowLabel predlbl,
      DataFlow::FlowLabel succlbl
    ) {
      predlbl = "firebase-ref" and
      succlbl = "firebase-ref" and
      pred = getReceiver() and
      succ = this
    }
  }

  /**
   * A step from `x` to `y` in `x.on("value", y => ...)`.
   */
  class RefListenerStep extends DataFlow::AdditionalFlowStep, DataFlow::MethodCallNode {
    RefListenerStep() {
      hasFirebaseTaintSource() and
      (getMethodName() = "on" or getMethodName() = "once") and
      getArgument(0).asExpr().getStringValue() = "value"
    }
  
    override predicate step(
      DataFlow::Node pred, DataFlow::Node succ, DataFlow::FlowLabel predlbl,
      DataFlow::FlowLabel succlbl
    ) {
      predlbl = "firebase-ref" and
      succlbl = "firebase-ref" and
      pred = getReceiver() and
      (
        succ = this // returns promise
        or
        succ = getCallback(1).getParameter(0)
      )
    }
  }

  /**
   * A step from `x` to `y` in `x.then(y => {})`.
   */
  class RefPromiseStep extends DataFlow::AdditionalFlowStep, DataFlow::MethodCallNode {
    DataFlow::Node dst;

    RefPromiseStep() {
      hasFirebaseTaintSource() and
      promiseTaintStep(this, dst)
    }
  
    override predicate step(
      DataFlow::Node pred, DataFlow::Node succ, DataFlow::FlowLabel predlbl,
      DataFlow::FlowLabel succlbl
    ) {
      predlbl = "firebase-ref" and
      succlbl = "firebase-ref" and
      pred = this and
      succ = dst
    }
  }
}
