/**
 * @name Wrong use of 'this' for static method
 * @description A reference to a static method from within an instance method needs to be qualified with the class name, not `this`.
 * @kind problem
 * @problem.severity error
 * @id js/mixed-static-instance-this-access
 * @tags correctness
 *       methods
 * @precision high
 */

import javascript

/** Holds if `cls` declares or inherits method `m` with the given `name`. */
DataFlow::FunctionNode getMethod(DataFlow::ClassNode cls, string name, string kind) {
  result = cls.getADirectSuperClass*().getAnInstanceMethod(name) and kind = "instance"
  or
  result = cls.getAStaticMethod(name) and kind = "static"
}

/** Holds if `cls` declares method `m` with the given `name`. */
DataFlow::FunctionNode getOwnMethod(DataFlow::ClassNode cls, string name, string kind) {
  result = cls.getAnInstanceMethod(name) and kind = "instance"
  or
  result = cls.getAStaticMethod(name) and kind = "static"
}

/**
 * Gets the AST node to use as alert location for the given method.
 */
ASTNode getNode(DataFlow::FunctionNode method) {
  exists(MethodDeclaration decl |
    decl.getBody() = method.getAstNode() and
    result = decl
  )
  or
  exists(ValueProperty prop |
    prop.getInit() = method.asExpr() and
    prop.isMethod() and
    result = prop
  )
  or
  not exists(MethodDeclaration decl | decl.getBody() = method.getAstNode()) and
  not exists(ValueProperty prop | prop.getInit() = method.asExpr() and prop.isMethod()) and
  result = method.getAstNode()
}

from
  DataFlow::ClassNode class_,
  DataFlow::PropRead access, DataFlow::FunctionNode fromMethod, DataFlow::FunctionNode toMethod, string fromKind,
  string toKind, string fromName
where
  fromMethod = getOwnMethod(class_, fromName, fromKind) and
  access = fromMethod.getReceiver().getAPropertyRead() and
  toMethod = getMethod(class_, access.getPropertyName(), toKind) and
  toKind != fromKind and
  // exceptions
  not (
    // the class has a second member with the same name and the right kind
    exists(getMethod(class_, access.getPropertyName(), fromKind))
    or
    // there is a dynamically assigned second member with the same name and the right kind
    exists(AnalyzedPropertyWrite apw, AbstractCallable declaringClass, AbstractValue base |
      "static" = fromKind and base = declaringClass
      or
      "instance" = fromKind and base = TAbstractInstance(declaringClass)
    |
      declaringClass.getFunction() = class_.getConstructor().getAstNode() and
      apw.writes(base, access.getPropertyName(), _)
    )
  )
select access,
  "Access to " + toKind + " method $@ from " + fromKind +
    " method $@ is not possible through `this`.", getNode(toMethod), access.getPropertyName(), getNode(fromMethod),
  fromName
