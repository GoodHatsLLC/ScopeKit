# ScopeKit
ScopeKit is a small Swift framework which makes it easy to scope the lifecycle for Combine based sections of an app.

## ScopeKit primitives

### Scope 
The core construct in ScopeKit is the [Scope](https://github.com/GoodHatsLLC/ScopeKit/blob/main/Sources/ScopeKit/Scope.swift)

```
public protocol ScopeType: ScopeOwningType {
    /// Allow this scope to act (iff attached to active superscope)
    func enable()

    /// Disable this scope (even if attached to active superscope)
    func disable()

    /// Bind the Scope's lifecycle to the passed Scope as a subscope.
    func attach(to superscope: ScopeOwningType)

    /// Remove the Scope from the lifecycle of its superscope.
    func detatch()
}

class MyViewModel: Scope {
    override func willStart() -> CancelBag {
        CancelBag {
          // my Combine actions
        }
    }
    
    override func willStop() {
      // Any non-combine teardown.
    }
}
 
```
Scopes are only active when they are both attatched to a parent and enabled.

Combine sinks defined in `willStart()` are activated when the scope is started and ended when the scope is stopped. It provides a `@resultBuilder` based API.

Scopes can be attatched to other Scopes as subscopes — including to the special-cased always on `ScopeRoot` which forms the base of the Scope tree.

### CancelBag

A cancel bag is a convenient container for Combine `AnyCancellable`s.

```
CancelBag {
  aPublisher.sink { _ in //actions }
  aSecondPublisher.sink { _ in //actions }
}
```

### Worker

Workers are a convenience handler for simple Combine routines which should not be able to have sub-routines. They're effectively single-level Scopes.
