/**
 * Provides classes and predicates for reasoning about string-manipulating expressions.
 */
import javascript

module StringConcatenation {
  /** Gets a data flow node referring to the result of the given concatenation. */
  private DataFlow::Node getAssignAddResult(AssignAddExpr expr) {
    result = expr.flow()
    or
    exists (SsaExplicitDefinition def | def.getDef() = expr |
      result = DataFlow::valueNode(def.getVariable().getAUse()))
  }

  /** Gets the `n`th operand to the string concatenation defining `node`. */
  DataFlow::Node getOperand(DataFlow::Node node, int n) {
    exists (AddExpr add | node = add.flow() |
      n = 0 and result = add.getLeftOperand().flow()
      or
      n = 1 and result = add.getRightOperand().flow())
    or
    exists (TemplateLiteral template | node = template.flow() |
      result = template.getElement(n).flow() and
      not exists (TaggedTemplateExpr tag | template = tag.getTemplate()))
    or
    exists (AssignAddExpr assign | node = getAssignAddResult(assign) |
      n = 0 and result = assign.getLhs().flow()
      or
      n = 1 and result = assign.getRhs().flow())
    or
    exists (DataFlow::ArrayCreationNode array, DataFlow::MethodCallNode call |
      call = array.getAMethodCall("join") and
      call.getArgument(0).mayHaveStringValue("") and
      (
        // step from array element to array
        result = array.getElement(n) and
        node = array
        or
        // step from array to join call
        node = call and
        result = array and
        n = 0
      ))
  }

  /** Gets an operand to the string concatenation defining `node`. */
  DataFlow::Node getAnOperand(DataFlow::Node node) {
    result = getOperand(node, _)
  }

  /** Gets the number of operands to the given concatenation. */
  int getNumOperand(DataFlow::Node node) {
    result = strictcount(getAnOperand(node))
  }

  /** Gets the first operand to the string concatenation defining `node`. */
  DataFlow::Node getFirstOperand(DataFlow::Node node) {
    result = getOperand(node, 0)
  }

  /** Gets the last operand to the string concatenation defining `node`. */
  DataFlow::Node getLastOperand(DataFlow::Node node) {
    result = getOperand(node, getNumOperand(node) - 1)
  }
  
  /**
   * Holds if `src` flows to `dst` through the `n`th operand of the given concatenation operator.
   */
  predicate taintStep(DataFlow::Node src, DataFlow::Node dst, DataFlow::Node operator, int n) {
    src = getOperand(dst, n) and
    operator = dst
  }

  /**
   * Holds if there is a taint step from `src` to `dst` through string concatenation.
   */
  predicate taintStep(DataFlow::Node src, DataFlow::Node dst) {
    taintStep(src, dst, _, _)
  }
}

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

/**
 * A expression that is equivalent to `A.includes(B)` or `!A.includes(B)`.
 */
abstract class StringContainsCheck extends DataFlow::Node {
  /** Gets the `A` in `A.includes(B)`. */
  abstract DataFlow::Node getBaseString();

  /** Gets the `B` in `A.includes(B)`. */
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
 * A call to a method named `includes`, assumed to refer to `String.prototype.includes`.
 */
private class NativeStringIncludesCheck extends StringContainsCheck, DataFlow::MethodCallNode {
  NativeStringIncludesCheck() {
    getMethodName() = "includes" and
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
 * A call to `_.includes`, assumed to operate on strings.
 */
private class LibraryStringIncludesCheck extends StringContainsCheck, DataFlow::CallNode {
  LibraryStringIncludesCheck() {
    this = LodashUnderscore::member("includes").getACall()
  }

  override DataFlow::Node getBaseString() {
    result = getArgument(0)
  }

  override DataFlow::Node getSubstring() {
    result = getArgument(1)
  }
}

/**
 * A check of form `A.indexOf(B) !== -1` or similar.
 */
private class IndexOfEqualsContainsCheck extends StringContainsCheck, DataFlow::ValueNode {
  MethodCallExpr indexOf;
  override EqualityTest astNode;

  IndexOfEqualsContainsCheck() {
    exists (Expr index | astNode.hasOperands(indexOf, index) |
      // one operand is of the form `whitelist.indexOf(x)`
      indexOf.getMethodName() = "indexOf" and
      // and the other one is -1
      index.getIntValue() = -1
    )
  }

  override DataFlow::Node getBaseString() {
    result = indexOf.getReceiver().flow()
  }

  override DataFlow::Node getSubstring() {
    result = indexOf.getArgument(0).flow()
  }

  override boolean getPolarity() {
    result = astNode.getPolarity().booleanNot()
  }
}

/**
 * A check of form `A.indexOf(B) >= 0` or similar.
 */
private class IndexOfRelationalContainsCheck extends StringContainsCheck, DataFlow::ValueNode {
  MethodCallExpr indexOf;
  override RelationalComparison astNode;
  boolean polarity;

  IndexOfRelationalContainsCheck() {
    exists (Expr lesser, Expr greater |
      astNode.getLesserOperand() = lesser and
      astNode.getGreaterOperand() = greater and
      indexOf.getMethodName() = "indexOf" and
      indexOf.getNumArgument() = 0 |
      polarity = true and
      greater = indexOf and
      (
        lesser.getIntValue() >= 0
        or
        lesser.getIntValue() = -1 and not astNode.isInclusive()
      )
      or 
      polarity = false and
      lesser = indexOf and
      (
        greater.getIntValue() = -1
        or
        greater.getIntValue() = 0 and not astNode.isInclusive()
      )
    )
  }

  override DataFlow::Node getBaseString() {
    result = indexOf.getReceiver().flow()
  }

  override DataFlow::Node getSubstring() {
    result = indexOf.getArgument(0).flow()
  }

  override boolean getPolarity() {
    result = polarity
  }
}

/**
 * An expression of form `~A.indexOf(B)` which, when coerced to a boolean, is equivalent to `A.includes(B)`.
 */
private class IndexOfBitwiseContainsCheck extends StringContainsCheck, DataFlow::ValueNode {
  MethodCallExpr indexOf;
  override BitNotExpr astNode;

  IndexOfBitwiseContainsCheck() {
    astNode.getOperand() = indexOf and
    indexOf.getMethodName() = "indexOf"
  }

  override DataFlow::Node getBaseString() {
    result = indexOf.getReceiver().flow()
  }

  override DataFlow::Node getSubstring() {
    result = indexOf.getArgument(0).flow()
  }
}
