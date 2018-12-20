/**
 * Provides classes and predicates for recognizing `startsWith` calls and their equivalents.
 */
import javascript

/**
 * A expression that is equivalent to `A.startsWith(B)` or `!A.startsWith(B)`.
 */
abstract class StartsWithCheck extends DataFlow::Node {
  /**
   * Gets the `A` in `A.startsWith(B)`.
   */
  abstract DataFlow::Node getBaseString();

  /**
   * Gets the `B` in `A.startsWith(B)`.
   */
  abstract DataFlow::Node getSubstring();

  /**
   * Gets the polarity if the check.
   *
   * If the polarity is `false` the check returns `true` if the string does not start
   * with the given substring.
   */
  boolean getPolarity() { result = true }
}

/**
 * An expression of form `A.startsWith(B)`.
 */
private class NativeStartsWith extends StartsWithCheck, DataFlow::MethodCallNode {
  NativeStartsWith() {
    getMethodName() = "startsWith" and
    getNumArgument() = 1
  }

  override DataFlow::Node getBaseString() {
    result = getReceiver()
  }

  override DataFlow::Node getSubstring() {
    result = getArgument(0)
  }
}

/**
 * An expression of form `A.indexOf(B) === 0`.
 */
private class IndexOfStartsWith extends StartsWithCheck, DataFlow::ValueNode {
  override EqualityTest astNode;
  DataFlow::MethodCallNode indexOf;

  IndexOfStartsWith() {
    indexOf.getMethodName() = "indexOf" and
    indexOf.getNumArgument() = 1 and
    indexOf.flowsToExpr(astNode.getAnOperand()) and
    astNode.getAnOperand().getIntValue() = 0
  }

  override DataFlow::Node getBaseString() {
    result = indexOf.getReceiver()
  }

  override DataFlow::Node getSubstring() {
    result = indexOf.getArgument(0)
  }

  override boolean getPolarity() {
    result = astNode.getPolarity()
  }
}

/**
 * An expression of form `A.indexOf(B)` coerced to a boolean.
 *
 * This is equivalent to `!A.startsWith(B)` since all return values other than zero map to `true`.
 */
private class IndexOfCoercionStartsWith extends StartsWithCheck, DataFlow::MethodCallNode {
  IndexOfCoercionStartsWith() {
    getMethodName() = "indexOf" and
    getNumArgument() = 1 and
    this.flowsToExpr(any(ConditionGuardNode guard).getTest()) // check for boolean coercion
  }

  override DataFlow::Node getBaseString() {
    result = getReceiver()
  }

  override DataFlow::Node getSubstring() {
    result = getArgument(0)
  }

  override boolean getPolarity() {
    result = false
  }
}

/**
 * A call of form `_.startsWith(A, B)` or `ramda.startsWith(A, B)`.
 */
private class LibraryStartsWith extends StartsWithCheck, DataFlow::CallNode {
  LibraryStartsWith() {
    getNumArgument() = 2 and
    exists (DataFlow::SourceNode callee | this = callee.getACall() |
      callee = LodashUnderscore::member("startsWith") or
      callee = DataFlow::moduleMember("ramda", "startsWith")
    )
  }

  override DataFlow::Node getBaseString() {
    result = getArgument(0)
  }

  override DataFlow::Node getSubstring() {
    result = getArgument(1)
  }
}

/**
 * A comparison of form `x[0] === "k"` for some single-character constant `k`.
 */
private class FirstCharacterCheck extends StartsWithCheck, DataFlow::ValueNode {
  override EqualityTest astNode;
  DataFlow::PropRead read;
  Expr constant;
  
  FirstCharacterCheck() {
    read.flowsTo(astNode.getAnOperand().flow()) and
    read.getPropertyNameExpr().getIntValue() = 0 and
    constant.getStringValue().length() = 1 and
    astNode.getAnOperand() = constant
  }

  override DataFlow::Node getBaseString() {
    result = read.getBase()
  }

  override DataFlow::Node getSubstring() {
    result = constant.flow()
  }

  override boolean getPolarity() {
    result = astNode.getPolarity()
  }
}
