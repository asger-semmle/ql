/**
 * Provides classes and predicates for reasoning about the ordering of side effects
 * on a value.
 */
import javascript

module EffectTracking {
  private import semmle.javascript.dataflow.internal.FlowSteps as FlowSteps

  abstract class Configuration extends string {
    bindingset[this]
    Configuration() { any() }

    /**
     * Holds if the operation at the given location has an effect on the given value,
     * in a way that matters for this effect tracking configuration.
     */
    abstract predicate isTrackedSideEffect(ControlFlowNode loc, DataFlow::SourceNode value);

    /**
     * Holds if a function call itself should be marked as a side effect if the
     * callee has side effects.
     */
    predicate shouldSummarizeCalls() { any() }

    /**
     * Holds if the operation at the given location has an effect on the given value,
     * or (transitively) calls a function that performs side effects on the value.
     */
    predicate hasSideEffect(ControlFlowNode loc, DataFlow::SourceNode value) {
      isTrackedSideEffect(loc, value) or
      calleeHasSideEffects(DataFlow::valueNode(loc), value)
    }

    /**
     * Holds if the given function has a side effect that manipulates `value`.
     */
    predicate functionHasSideEffects(Function f, DataFlow::SourceNode value) {
      exists (ControlFlowNode loc |
        hasSideEffect(loc, value) and
        loc.getContainer() = f)
    }

    /**
     * Holds if the function invoked by `invoke` performs side effects on the given value
     * passed into the call.
     */
    predicate calleeHasSideEffects(DataFlow::InvokeNode invoke, DataFlow::SourceNode value) {
      shouldSummarizeCalls() and
      (
        // Passed as argument
        exists (DataFlow::Node arg, Function target, Parameter param |
          FlowSteps::argumentPassing(invoke, arg, target, param) and
          value.flowsTo(arg) and
          functionHasSideEffects(target, DataFlow::parameterNode(param)))
        or
        // Captured by nested function
        exists (Function target |
          target = invoke.getACallee() and
          functionHasSideEffects(target, value))
      )
    }

    /**
     * Holds if the given basic block has a effect on the given value.
     */
    private predicate basicBlockHasSideEffects(ReachableBasicBlock block, DataFlow::SourceNode value) {
      exists (ControlFlowNode loc | 
        loc.getBasicBlock() = block and
        hasSideEffect(loc, value))
    }

    /**
     * Gets the last side effect to reach `loc`, unless `loc` is an internal node in a basic block
     * without any side effects.
     *
     * In the latter case, the last effect should be obtained using `getSummarizedSideEffectInBasicBlock`.
     */
    private ControlFlowNode getLastSideEffectAtInternalNode(ControlFlowNode loc, DataFlow::SourceNode value) {
      if hasSideEffect(loc, value) then
        result = loc
      else if isStartOfBasicBlock(loc) then
        exists (ControlFlowNode pred | pred = loc.getAPredecessor() |
          if basicBlockHasSideEffects(pred.getBasicBlock(), value) then
            result = getLastSideEffectAtInternalNode(pred, value)
          else
            result = getLastSideEffectAtInternalNode(pred.getBasicBlock().getFirstNode(), value))
      else if basicBlockHasSideEffects(loc.getBasicBlock(), value) then
        result = getLastSideEffectAtInternalNode(loc.getAPredecessor(), value)
      else
        none() // don't store the recent effect on internal nodes
    }

    /**
     * Gets the last side effect to reach the given basic block, assuming the block has no side effects of its own.
     */
    private ControlFlowNode getSummarizedSideEffectInBasicBlock(BasicBlock block, DataFlow::SourceNode value) {
      result = getLastSideEffectAtInternalNode(block.getFirstNode(), value)
      and not basicBlockHasSideEffects(block, value)
    }

    /**
     * Gets the last side effect to affect the given value at the given location.
     */
    pragma[inline]
    ControlFlowNode getLastSideEffect(ControlFlowNode loc, DataFlow::SourceNode value) {
      result = getLastSideEffectAtInternalNode(loc, value)
      or
      result = getSummarizedSideEffectInBasicBlock(loc.getBasicBlock(), value)
    }

    /**
     * Gets the last operation to affect the given value before the given function returns.
     */
    ControlFlowNode getLastSideEffectInFunction(Function f, DataFlow::SourceNode value) {
      result = getLastSideEffect(f.getExit(), value)
    }

    /**
     * Gets the last operation to affect the given value inside the callee of `invoke`.
     *
     * `value` refers to the value passed to the call, and `calleeAlias` refers to its local alias in the callee.
     */
    ControlFlowNode getLastSideEffectInCallee(DataFlow::InvokeNode invoke, DataFlow::SourceNode value, DataFlow::SourceNode calleeAlias) {
      shouldSummarizeCalls() and
      (
        // Passed as argument
        exists (Function target, Parameter parm, DataFlow::Node arg |
          FlowSteps::argumentPassing(invoke, arg, target, parm) and
          value.flowsTo(arg) and
          calleeAlias = DataFlow::parameterNode(parm) and
          result = getLastSideEffectInFunction(target, calleeAlias))
        or
        // Returned from function
        exists (Function target |
          target = invoke.getACallee() and
          value = invoke and
          calleeAlias = target.getAReturnedExpr().flow().getALocalSource() and
          result = getLastSideEffectInFunction(target, calleeAlias))
        or
        // Captured by nested function
        exists (Function target |
          target = invoke.getACallee() and
          value.getContainer() != target and
          result = getLastSideEffectInFunction(target, value) and
          calleeAlias = value)
      )
    }
  }

  private predicate isStartOfBasicBlock(ControlFlowNode node) {
    exists (BasicBlock b | b.getFirstNode() = node)
  }
}
