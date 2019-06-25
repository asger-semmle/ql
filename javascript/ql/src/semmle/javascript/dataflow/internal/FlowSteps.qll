/**
 * INTERNAL: Do not use directly.
 *
 * Provides auxiliary predicates for defining inter-procedural data flow configurations.
 */

import javascript
import semmle.javascript.dataflow.Configuration

/**
 * Holds if flow should be tracked through properties of `obj`.
 *
 * Flow is tracked through object literals, `module` and `module.exports` objects.
 */
predicate shouldTrackProperties(AbstractValue obj) {
  obj instanceof AbstractExportsObject or
  obj instanceof AbstractModuleObject
}

/**
 * Holds if `source` corresponds to an expression returned by `f`, and
 * `sink` equals `source`.
 */
pragma[noinline]
predicate returnExpr(Function f, DataFlow::Node source, DataFlow::Node sink) {
  sink.asExpr() = f.getAReturnedExpr() and source = sink
}

/**
 * Holds if data can flow in one step from `pred` to `succ`,  taking
 * additional steps from the configuration into account.
 */
pragma[inline]
predicate localFlowStep(
  DataFlow::Node pred, DataFlow::Node succ, DataFlow::Configuration configuration,
  FlowLabel predlbl, FlowLabel succlbl
) {
  pred = succ.getAPredecessor() and predlbl = succlbl
  or
  any(DataFlow::AdditionalFlowStep afs).step(pred, succ) and predlbl = succlbl
  or
  any(DataFlow::AdditionalFlowStep afs).step(pred, succ, predlbl, succlbl)
  or
  exists(boolean vp | configuration.isAdditionalFlowStep(pred, succ, vp) |
    vp = true and
    predlbl = succlbl
    or
    vp = false and
    (predlbl = FlowLabel::data() or predlbl = FlowLabel::taint()) and
    succlbl = FlowLabel::taint()
  )
  or
  configuration.isAdditionalFlowStep(pred, succ, predlbl, succlbl)
  or
  localExceptionStep(pred, succ) and
  predlbl = succlbl
}

/**
 * Holds if an exception thrown from `pred` can propagate locally to `succ`.
 */
predicate localExceptionStep(DataFlow::Node pred, DataFlow::Node succ) {
  exists(Expr expr |
    expr = any(ThrowStmt throw).getExpr() and
    pred = expr.flow()
    or
    DataFlow::exceptionalInvocationReturnNode(pred, expr)
  |
    // Propagate out of enclosing function.
    not exists(getEnclosingTryStmt(expr.getEnclosingStmt())) and
    exists(Function f |
      f = expr.getEnclosingFunction() and
      DataFlow::exceptionalFunctionReturnNode(succ, f)
    )
    or
    // Propagate to enclosing try/catch.
    // To avoid false flow, we only propagate to an unguarded catch clause.
    exists(TryStmt try |
      try = getEnclosingTryStmt(expr.getEnclosingStmt()) and
      DataFlow::parameterNode(succ, try.getCatchClause().getAParameter())
    )
  )
}

/**
 * Defines the stage 1 call graph.
 *
 * This call graph is derived from the type inference and static type information.
 *
 * Predicates suffixed with `_v1` are specific to the stage 1 call graph.
 */
private module CallGraph_v1 {
  /**
   * Holds if the stage 1 call graph has an edge from `invoke` to `target`.
   */
  predicate callEdge(DataFlow::InvokeNode invoke, Function target) {
    target = invoke.getACallee(0)
  }
}

/**
 * Defines the stage 2 call graph.
 *
 * This call graph is derived from the first stage using type tracking.
 *
 * Predicates suffixed with `_v2_delta` are specific to the stage 2 call graph.
 */
private module CallGraph_v2 {
  /**
   * Gets a source node that may refer to the given class.
   */
  DataFlow::SourceNode getAReferenceToClass(DataFlow::ClassNode cls, DataFlow::TypeTracker t) {
    t.start() and
    result = cls
    or
    exists(DataFlow::TypeTracker t2 |
      result = getAReferenceToClass(cls, t2).track(t2, t)
    )
  }

  DataFlow::SourceNode getAReferenceToClass(DataFlow::ClassNode cls) {
    result = getAReferenceToClass(cls, DataFlow::TypeTracker::end())
  }

  /**
   * Gets the name of the given class, as specified by its `@name` JSDoc tag.
   */
  string getNameTagOfClass(DataFlow::ClassNode cls) {
    exists(JSDoc doc |
      doc = cls.getAstNode().(Documentable).getDocumentation()
      or
      doc = cls.getConstructor().getFunction().(Documentable).getDocumentation()
    |
      result = doc.getATagByTitle("name").getName()
    )
  }

  /**
   * Holds if exactly one class is annotated with the given JSDoc `@name`.
   */
  predicate isUniqueClassName(string name) {
    strictcount(DataFlow::ClassNode cls | getNameTagOfClass(cls) = name) = 1
  }

  /**
   * Gets the canonical name of the given class.
   */
  string getCanonicalNameOfClass(DataFlow::ClassNode cls) {
    result = getNameTagOfClass(cls) and
    isUniqueClassName(result)
  }

  /**
   * Gets the JSDoc type annotation describing the type of the given node, if any.
   */
  JSDocTypeExpr getJSDocTypeFromSourceNode(DataFlow::SourceNode node) {
    exists(Parameter param |
      node = DataFlow::parameterNode(param) and
      result = param.getJSDocTag().getType()
    )
    or
    exists(Function target |
      CallGraph_v1::callEdge(node, target) and
      result = target.getReturnTypeAnnotation()
    )
  }

  /**
   * Gets a source node that may refer to an instance of the given class.
   */
  DataFlow::SourceNode getAnInstanceOf(DataFlow::ClassNode cls, DataFlow::TypeTracker t) {
    result = getAReferenceToClass(cls, t.continue()).getAnInstantiation()
    or
    t.start() and
    result = cls.getAReceiverNode()
    or
    t.start() and
    getJSDocTypeFromSourceNode(result).hasQualifiedName(getCanonicalNameOfClass(cls))
    or
    exists(DataFlow::TypeTracker t2 |
      result = getAnInstanceOf(cls, t2).track(t2, t)
    )
  }

  /**
   * Gets a source node that may refer to an instance of the given class.
   */
  DataFlow::SourceNode getAnInstanceOf(DataFlow::ClassNode cls) {
    result = getAnInstanceOf(cls, DataFlow::TypeTracker::end())
  }

  /**
   * Holds if `subclass` is a direct subclass of `superclass`.
   */
  predicate isDirectSubclassOf(DataFlow::ClassNode subclass, DataFlow::ClassNode superclass) {
    getAReferenceToClass(superclass).flowsTo(subclass.getASuperClassNode())
  }

  /**
   * Gets the instance method of the given name in `cls`, taking inheritance into account.
   */
  DataFlow::FunctionNode getInheritedInstanceMethod(DataFlow::ClassNode cls, string name) {
    result = cls.getInstanceMethod(name)
    or
    exists(DataFlow::ClassNode superclass |
      isDirectSubclassOf(cls, superclass) and
      result = getInheritedInstanceMethod(superclass, name) and
      not exists(cls.getAnInstanceMember(name))
    )
  }

  /**
   * Holds if the method invoked by `invoke` resolved to a member named `name` in `cls`
   * or one of its super classes.
   *
   * TODO: Currently unused, but kept as alternative to `getInheritedInstanceMethod`.
   * Remove once experiments conclude which predicate to use.
   */
  predicate callResolvesToClass(DataFlow::InvokeNode invoke, DataFlow::ClassNode cls, string name) {
    invoke = getAnInstanceOf(cls).getAMethodCall(name)
    or
    exists(DataFlow::ClassNode subclass |
      callResolvesToClass(invoke, subclass, name) and
      not exists(subclass.getAnInstanceMember(name)) and
      isDirectSubclassOf(subclass, cls)
    )
  }

  /**
   * Holds if the stage 2 call graph has an edge from `invoke` to `target`.
   */
  predicate callEdge(DataFlow::InvokeNode invoke, Function target) {
    exists(DataFlow::ClassNode cls, string name |
      callResolvesToClass(invoke, cls, name) and
      target = cls.getInstanceMethod(name).getFunction()
    )
  }
}

/**
 * Implements a set of data flow predicates that are used by multiple predicates and
 * hence should only be computed once.
 */
cached
private module CachedSteps {
  /**
   * Holds if `f` captures the variable defined by `def` in `cap`.
   */
  cached
  predicate captures(Function f, SsaExplicitDefinition def, SsaVariableCapture cap) {
    def.getSourceVariable() = cap.getSourceVariable() and
    f = cap.getContainer()
  }

  /**
   * Holds if `invk` may invoke `f`.
   */
  cached
  predicate calls_v1(DataFlow::InvokeNode invk, Function f) { CallGraph_v1::callEdge(invk, f) }

  /**
   * Holds if `invk` may invoke `f`.
   */
  private
  predicate calls_v2_delta(DataFlow::InvokeNode invk, Function f) { CallGraph_v2::callEdge(invk, f) }

  /**
   * Holds if `invk` may invoke `f`.
   */
  cached
  predicate calls(DataFlow::InvokeNode invk, Function f) {
    calls_v1(invk, f)
    or
    calls_v2_delta(invk, f)
  }

  /**
   * Holds if `invk` may invoke `f` indirectly through the given `callback` argument.
   *
   * This only holds for explicitly modeled partial calls.
   */
  private predicate partiallyCalls(
    DataFlow::AdditionalPartialInvokeNode invk, DataFlow::AnalyzedNode callback, Function f
  ) {
    invk.isPartialArgument(callback, _, _) and
    exists(AbstractFunction callee | callee = callback.getAValue() |
      if callback.getAValue().isIndefinite("global")
      then f = callee.getFunction() and f.getFile() = invk.getFile()
      else f = callee.getFunction()
    )
  }

  /**
   * A version of `argumentPassing`, restricted to using the edges from the stage 1 call graph.
   */
  cached
  predicate argumentPassing_v1(
    DataFlow::InvokeNode invk, DataFlow::ValueNode arg, Function f, DataFlow::ParameterNode parm
  ) {
    calls_v1(invk, f) and
    exists(int i |
      f.getParameter(i) = parm.getParameter() and
      not parm.isRestParameter() and
      arg = invk.getArgument(i)
    )
    or
    exists(DataFlow::Node callback, int i |
      invk.(DataFlow::AdditionalPartialInvokeNode).isPartialArgument(callback, arg, i) and
      partiallyCalls(invk, callback, f) and
      parm.getParameter() = f.getParameter(i) and
      not parm.isRestParameter()
    )
  }
  
  /**
   * A version of `argumentPassing`, restricted to edges specific to the stage 2 call graph.
   */
  private predicate argumentPassing_v2_delta(
    DataFlow::InvokeNode invk, DataFlow::ValueNode arg, Function f, DataFlow::ParameterNode parm
  ) {
    calls_v2_delta(invk, f) and
    exists(int i |
      f.getParameter(i) = parm.getParameter() and
      not parm.isRestParameter() and
      arg = invk.getArgument(i)
    )
  }

  /**
   * Holds if `arg` is passed as an argument into parameter `parm`
   * through invocation `invk` of function `f`.
   *
   * Restricted to using the edges specific to the stage 2 call graph.
   */
  cached
  predicate argumentPassing(
    DataFlow::InvokeNode invk, DataFlow::ValueNode arg, Function f, DataFlow::ParameterNode parm
  ) {
    argumentPassing_v1(invk, arg, f, parm)
    or
    argumentPassing_v2_delta(invk, arg, f, parm)
  }

  /**
   * A version of `callStep`, restricted to using edges from the stage 1 call graph.
   */
  cached
  predicate callStep_v1(DataFlow::Node pred, DataFlow::Node succ) { argumentPassing_v1(_, pred, _, succ) }

  /**
   * Holds if there is a flow step from `pred` to `succ` through parameter passing
   * to a function call.
   */
  cached
  predicate callStep(DataFlow::Node pred, DataFlow::Node succ) {
    callStep_v1(pred, succ)
    or
    argumentPassing_v2_delta(_, pred, _, succ)
  }

  /**
   * Gets the `try` statement containing `stmt` without crossing function boundaries
   * or other `try ` statements.
   */
  cached
  TryStmt getEnclosingTryStmt(Stmt stmt) {
    result.getBody() = stmt
    or
    not stmt instanceof Function and
    not stmt = any(TryStmt try).getBody() and
    result = getEnclosingTryStmt(stmt.getParentStmt())
  }

  /**
   * A version of `returnStep`, restricted to using edges from the stage 1 call graph.
   */
  cached
  predicate returnStep_v1(DataFlow::Node pred, DataFlow::Node succ) {
    exists(Function f | calls_v1(succ, f) |
      returnExpr(f, pred, _)
      or
      succ instanceof DataFlow::NewNode and
      DataFlow::thisNode(pred, f)
    )
    or
    exists(InvokeExpr invoke, Function fun |
      DataFlow::exceptionalFunctionReturnNode(pred, fun) and
      DataFlow::exceptionalInvocationReturnNode(succ, invoke) and
      calls_v1(invoke.flow(), fun)
    )
  }
  
  /**
   * A version of `returnStep`, restricted to using edges specific to the stage 2 call graph.
   */
  private predicate returnStep_v2_delta(DataFlow::Node pred, DataFlow::Node succ) {
    exists(Function f | calls_v2_delta(succ, f) |
      returnExpr(f, pred, _)
      or
      succ instanceof DataFlow::NewNode and
      DataFlow::thisNode(pred, f)
    )
    or
    exists(InvokeExpr invoke, Function fun |
      DataFlow::exceptionalFunctionReturnNode(pred, fun) and
      DataFlow::exceptionalInvocationReturnNode(succ, invoke) and
      calls_v2_delta(invoke.flow(), fun)
    )
  }

  /**
   * Holds if there is a flow step from `pred` to `succ` through:
   * - returning a value from a function call, or
   * - throwing an exception out of a function call, or
   * - the receiver flowing out of a constructor call.
   */
  cached
  predicate returnStep(DataFlow::Node pred, DataFlow::Node succ) {
    returnStep_v1(pred, succ)
    or
    returnStep_v2_delta(pred, succ)
  }

  /**
   * Holds if there is an assignment to property `prop` of an object represented by `obj`
   * with right hand side `rhs` somewhere, and properties of `obj` should be tracked.
   */
  pragma[noinline]
  private predicate trackedPropertyWrite(AbstractValue obj, string prop, DataFlow::Node rhs) {
    exists(AnalyzedPropertyWrite pw |
      pw.writes(obj, prop, rhs) and
      shouldTrackProperties(obj) and
      // avoid introducing spurious global flow
      not pw.baseIsIncomplete("global")
    )
  }

  /**
   * Holds if there is a flow step from `pred` to `succ` through an object property.
   */
  cached
  predicate propertyFlowStep(DataFlow::Node pred, DataFlow::Node succ) {
    exists(AbstractValue obj, string prop |
      trackedPropertyWrite(obj, prop, pred) and
      succ.(AnalyzedPropertyRead).reads(obj, prop)
    )
  }

  /**
   * Gets a node whose value is assigned to `gv` in `f`.
   */
  pragma[noinline]
  private DataFlow::ValueNode getADefIn(GlobalVariable gv, File f) {
    exists(VarDef def |
      def.getFile() = f and
      def.getTarget() = gv.getAReference() and
      result = DataFlow::valueNode(def.getSource())
    )
  }

  /**
   * Gets a use of `gv` in `f`.
   */
  pragma[noinline]
  private DataFlow::ValueNode getAUseIn(GlobalVariable gv, File f) {
    result.getFile() = f and
    result = DataFlow::valueNode(gv.getAnAccess())
  }

  /**
   * Holds if there is a flow step from `pred` to `succ` through a global
   * variable. Both `pred` and `succ` must be in the same file.
   */
  cached
  predicate globalFlowStep(DataFlow::Node pred, DataFlow::Node succ) {
    exists(GlobalVariable gv, File f |
      pred = getADefIn(gv, f) and
      succ = getAUseIn(gv, f)
    )
  }

  /**
   * Holds if there is a write to property `prop` of global variable `gv`
   * in file `f`, where the right-hand side of the write is `rhs`.
   */
  pragma[noinline]
  private predicate globalPropertyWrite(GlobalVariable gv, File f, string prop, DataFlow::Node rhs) {
    exists(DataFlow::PropWrite pw | pw.writes(getAUseIn(gv, f), prop, rhs))
  }

  /**
   * Holds if there is a read from property `prop` of `base`, which is
   * an access to global variable `base` in file `f`.
   */
  pragma[noinline]
  private predicate globalPropertyRead(GlobalVariable gv, File f, string prop, DataFlow::Node base) {
    exists(DataFlow::PropRead pr |
      base = getAUseIn(gv, f) and
      pr.accesses(base, prop)
    )
  }

  /**
   * Holds if there is a store step from `pred` to `succ` under property `prop`,
   * that is, `succ` is the local source of the base of a write of property
   * `prop` with right-hand side `pred`.
   *
   * For example, for this code snippet:
   *
   * ```
   * var a = new A();
   * a.p = e;
   * ```
   *
   * there is a store step from `e` to `new A()` under property `prop`.
   *
   * As a special case, if the base of the property write is a global variable,
   * then there is a store step from the right-hand side of the write to any
   * read of the same property from the same global variable in the same file.
   */
  cached
  predicate basicStoreStep(DataFlow::Node pred, DataFlow::Node succ, string prop) {
    succ.(DataFlow::SourceNode).hasPropertyWrite(prop, pred)
    or
    exists(GlobalVariable gv, File f |
      globalPropertyWrite(gv, f, prop, pred) and
      globalPropertyRead(gv, f, prop, succ)
    )
  }

  /**
   * Holds if there is a load step from `pred` to `succ` under property `prop`,
   * that is, `succ` is a read of property `prop` from `pred`.
   */
  cached
  predicate loadStep(DataFlow::Node pred, DataFlow::PropRead succ, string prop) {
    succ.accesses(pred, prop)
  }

  /**
   * Holds if there is a higher-order call with argument `arg`, and `cb` is the local
   * source of an argument that flows into the callee position of that call:
   *
   * ```
   * function f(x, g) {
   *   g(
   *     x                 // arg
   *   );
   * }
   *
   * function cb() {      // cb
   * }
   *
   * f(arg, cb);
   *
   * This is an over-approximation of a possible data flow step through a callback
   * invocation.
   */
  cached
  predicate callback(DataFlow::Node arg, DataFlow::SourceNode cb) {
    exists(DataFlow::InvokeNode invk, DataFlow::ParameterNode cbParm, DataFlow::Node cbArg |
      arg = invk.getAnArgument() and
      cbParm.flowsTo(invk.getCalleeNode()) and
      callStep(cbArg, cbParm) and
      cb.flowsTo(cbArg)
    )
    or
    exists(DataFlow::ParameterNode cbParm, DataFlow::Node cbArg |
      callback(arg, cbParm) and
      callStep(cbArg, cbParm) and
      cb.flowsTo(cbArg)
    )
  }

  /**
   * Holds if `f` may return `base`, which has a write of property `prop` with right-hand side `rhs`.
   */
  cached
  predicate returnedPropWrite(Function f, DataFlow::SourceNode base, string prop, DataFlow::Node rhs) {
    base.hasPropertyWrite(prop, rhs) and
    base.flowsToExpr(f.getAReturnedExpr())
  }

  /**
   * Holds if `f` may assign `rhs` to `this.prop`.
   */
  cached
  predicate receiverPropWrite(Function f, string prop, DataFlow::Node rhs) {
    DataFlow::thisNode(f).hasPropertyWrite(prop, rhs)
  }
}
import CachedSteps

/**
 * A utility class that is equivalent to `boolean` but does not require type joining.
 */
class Boolean extends boolean {
  Boolean() { this = true or this = false }
}

/**
 * A summary of an inter-procedural data flow path.
 */
newtype TPathSummary =
  /** A summary of an inter-procedural data flow path. */
  MkPathSummary(Boolean hasReturn, Boolean hasCall, FlowLabel start, FlowLabel end)

/**
 * A summary of an inter-procedural data flow path.
 *
 * The summary includes a start flow label and an end flow label, and keeps track of
 * whether the path contains any call steps from an argument of a function call to the
 * corresponding parameter, and/or any return steps from the `return` statement of a
 * function to a call of that function.
 *
 * We only want to build properly matched call/return sequences, so if a path has both
 * call steps and return steps, all return steps must precede all call steps.
 */
class PathSummary extends TPathSummary {
  Boolean hasReturn;

  Boolean hasCall;

  FlowLabel start;

  FlowLabel end;

  PathSummary() { this = MkPathSummary(hasReturn, hasCall, start, end) }

  /** Indicates whether the path represented by this summary contains any unmatched return steps. */
  boolean hasReturn() { result = hasReturn }

  /** Indicates whether the path represented by this summary contains any unmatched call steps. */
  boolean hasCall() { result = hasCall }

  /** Holds if the path represented by this summary contains no unmatched call or return steps. */
  predicate isLevel() {
    hasReturn = false and hasCall = false
  }

  /** Gets the flow label describing the value at the start of this flow path. */
  FlowLabel getStartLabel() { result = start }

  /** Gets the flow label describing the value at the end of this flow path. */
  FlowLabel getEndLabel() { result = end }

  /**
   * Gets the summary for the path obtained by appending `that` to `this`.
   *
   * Note that a path containing a `return` step cannot be appended to a path containing
   * a `call` step in order to maintain well-formedness.
   */
  PathSummary append(PathSummary that) {
    exists(Boolean hasReturn2, Boolean hasCall2, FlowLabel end2 |
      that = MkPathSummary(hasReturn2, hasCall2, end, end2)
    |
      result = MkPathSummary(hasReturn.booleanOr(hasReturn2), hasCall.booleanOr(hasCall2), start,
          end2) and
      // avoid constructing invalid paths
      not (hasCall = true and hasReturn2 = true)
    )
  }

  /**
   * Gets the summary for the path obtained by appending `that` to `this`, where
   * `that` must be a path mapping `data` to `data` (in other words, it must be
   * a value-preserving path).
   */
  PathSummary appendValuePreserving(PathSummary that) {
    exists(Boolean hasReturn2, Boolean hasCall2 |
      that = MkPathSummary(hasReturn2, hasCall2, FlowLabel::data(), FlowLabel::data())
    |
      result = MkPathSummary(hasReturn.booleanOr(hasReturn2), hasCall.booleanOr(hasCall2), start,
          end) and
      // avoid constructing invalid paths
      not (hasCall = true and hasReturn2 = true)
    )
  }

  /**
   * Gets the summary for the path obtained by appending `this` to `that`.
   */
  PathSummary prepend(PathSummary that) { result = that.append(this) }

  /** Gets a textual representation of this path summary. */
  string toString() {
    exists(string withReturn, string withCall |
      (if hasReturn = true then withReturn = "with" else withReturn = "without") and
      (if hasCall = true then withCall = "with" else withCall = "without")
    |
      result = "path " + withReturn + " return steps and " + withCall + " call steps " +
          "transforming " + start + " into " + end
    )
  }
}

module PathSummary {
  /**
   * Gets a summary describing a path without any calls or returns.
   */
  PathSummary level() { result = level(_) }

  /**
   * Gets a summary describing a path without any calls or returns, transforming `lbl` into
   * itself.
   */
  PathSummary level(FlowLabel lbl) { result = MkPathSummary(false, false, lbl, lbl) }

  /**
   * Gets a summary describing a path with one or more calls, but no returns.
   */
  PathSummary call() { exists(FlowLabel lbl | result = MkPathSummary(false, true, lbl, lbl)) }

  /**
   * Gets a summary describing a path with one or more returns, but no calls.
   */
  PathSummary return() { exists(FlowLabel lbl | result = MkPathSummary(true, false, lbl, lbl)) }
}
