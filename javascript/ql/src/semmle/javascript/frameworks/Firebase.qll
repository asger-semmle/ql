import javascript

module Firebase {

  private DataFlow::SourceNode getANonLocalSuccessor(DataFlow::SourceNode node) {
    exists (DataFlow::ClassNode class_, string prop |
      class_.getConstructor().getReceiver().getAPropertySource(prop) = node and
      result = class_.getAnInstanceMethod().getReceiver().getAPropertyRead(prop)
    )
  }

  /** Gets a reference to the firebase API object. */
  private DataFlow::SourceNode firebase() {
    result = DataFlow::moduleImport("firebase/app")
    or
    result = DataFlow::globalVarRef("firebase")
    or
    result = getANonLocalSuccessor(firebase())
  }

  /** Gets a reference to a firebase app. */
  DataFlow::SourceNode app() {
    result = firebase()
    or
    result = firebase().getAMethodCall("initializeApp")
    or
    result = getANonLocalSuccessor(app())
  }

  /** Gets a reference to a firebase database object, such as `firebase.database()`. */
  DataFlow::SourceNode database() {
    result = app().getAMethodCall("database")
    or
    result = getANonLocalSuccessor(database())
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
