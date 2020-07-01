/**
 * Provides classes and predicates for reasoning about code using the Firebase API.
 */

import javascript
private import ApiGraphs

module Firebase {
  /** Gets a reference to the `firebase/app` or `firebase-admin` API object. */
  LocalApiGraph::Node firebase() {
    result = LocalApiGraph::moduleImport(["npm:firebase/app", "npm:firebase-admin"])
  }

  /**
   * Gets a reference to a Firebase app, either the `firebase` object or an
   * app created explicitly with `initializeApp()`.
   */
  LocalApiGraph::Node app() {
    result = firebase()
    or
    result = firebase().getMember("initializeApp").getReturn()
    // or
    // or result.isTypeName("firebase", "app.App")
  }

  module Database {
    /** Gets a reference to a Firebase database object, such as `firebase.database()`. */
    LocalApiGraph::Node database() {
      result = app().getMember("database").getReturn()
    }

    /** Gets a node that refers to a `Reference` object, such as `firebase.database().ref()`. */
    LocalApiGraph::Node ref() {
      result = database().getMember(["ref", "refFromURL"]).getReturn()
      or
      result = ref().getMember(["push", "child"]).getReturn()
      or
      result = ref().getMember(["parent", "root"])
      or
      result = snapshot().getMember("ref")
      // or
      // or result.isTypeName("firebase", "database.Reference")
    }

    /** Gets a node that refers to a `Query` or `Reference` object. */
    LocalApiGraph::Node query() {
      result = ref()
      or
      result = query().getMember(["endAt", "startAt", ["limitTo", "order"] + any(string s)]).getReturn()
      // or
      // or result.isTypeName("firebase", "database.Query")
    }

    LocalApiGraph::Node queryListenFunc() {
      result = query().getMember(["on", "once"])
    }

    LocalApiGraph::Node queryListenCallback() {
      result = queryListenFunc().getParameter(1)
    }

    /**
     * Gets a node that is passed as the callback to a `Reference.transaction` call.
     */
    LocalApiGraph::Node transactionCallback() {
      result = ref().getMember("transaction").getParameter(0)
    }
  }

  /**
   * Provides predicates for reasoning about the the Firebase Cloud Functions API,
   * sometimes referred to just as just "Firebase Functions".
   */
  module CloudFunctions {
    /** Gets a reference to the Cloud Functions namespace. */
    LocalApiGraph::Node namespace() {
      result = LocalApiGraph::moduleImport("npm:firebase-functions")
    }

    /** Gets a reference to a Cloud Functions database object. */
    LocalApiGraph::Node database() {
      result = namespace().getMember("database")
    }

    /** Gets a data flow node holding a `RefBuilder` object. */
    LocalApiGraph::Node ref() {
      result = database().getMember("ref").getReturn()
    }

    LocalApiGraph::Node refBuilderListenCallback() {
      result = ref().getMember("on" + any(string s)).getParameter(0)
    }

    /**
     * A call to a Firebase method that sets up a route.
     */
    private class RouteSetup extends HTTP::Servers::StandardRouteSetup, CallExpr {
      RouteSetup() {
        this = namespace().getMember("https").getMember("onRequest").getReturn().asDataFlowNode().asExpr()
      }

      override DataFlow::SourceNode getARouteHandler() {
        result = getARouteHandler(DataFlow::TypeBackTracker::end())
      }

      private DataFlow::SourceNode getARouteHandler(DataFlow::TypeBackTracker t) {
        t.start() and
        result = getArgument(0).flow().getALocalSource()
        or
        exists(DataFlow::TypeBackTracker t2 | result = getARouteHandler(t2).backtrack(t2, t))
      }

      override Expr getServer() { none() }
    }

    /**
     * A function used as a route handler.
     */
    private class RouteHandler extends Express::RouteHandler, HTTP::Servers::StandardRouteHandler,
      DataFlow::ValueNode {
      override Function astNode;

      RouteHandler() { this = any(RouteSetup setup).getARouteHandler() }

      override SimpleParameter getRouteHandlerParameter(string kind) {
        kind = "request" and result = astNode.getParameter(0)
        or
        kind = "response" and result = astNode.getParameter(1)
      }
    }
  }

  /**
   * Gets a value that will be invoked with a `DataSnapshot` value as its first parameter.
   */
  LocalApiGraph::Node snapshotCallback() {
    result = Database::queryListenCallback()
    or
    result = CloudFunctions::refBuilderListenCallback()
  }

  /**
   * Gets a node that refers to a `DataSnapshot` value, such as `x` in
   * `firebase.database().ref().on('value', x => {...})`.
   */
  LocalApiGraph::Node snapshot() {
    result = snapshotCallback().getParameter(0)
    or
    result = Database::queryListenFunc().getReturn() // returns promise
    or
    result = snapshot().getMember("child").getReturn()
    or
    result = snapshot().getMember("forEach").getParameter(0).getParameter(0)
    or
    result = snapshot().getMember(["before", "after"])
    // or
    // result.isTypeName("firebase", "database.DataSnapshot")
    //
    // Unable to port: promiseTaintStep(snapshot(t), result)
  }

  /**
   * A reference to a value obtained from a Firebase database.
   */
  class FirebaseVal extends RemoteFlowSource {
    FirebaseVal() {
      this = snapshot().getMember(["val", "exportVal"]).getReturn().asDataFlowNode()
      or
      this = Database::transactionCallback().getParameter(0).asDataFlowNode()
    }

    override string getSourceType() { result = "Firebase database" }
  }
}
