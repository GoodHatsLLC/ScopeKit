import Foundation


/**
The states a Scope or Behavior can be in.

 `detached`
 * Not attached to a superscope.
 * May activate or be disposed.

 `attached`
 * Attached to a superscope, but it or an ancestor are detached.
 * Not currently doing any work. May activate or detach.

 `active`
 * Has started and is actively performing its behavior.
 * Attached to an active scope. Will deactivate.

```

 ┌────────────┐  willAttach   ┌────────────┐ willActivate ┌────────────┐
 │  Detached  │──────────────▶│  Attached  │─────────────▶│   Active   │
 └────────────┘               └────────────┘              └────────────┘
        ▲                         │    ▲                        │
        │                         │    │                        │
        └─────────────────────────┘    └────────────────────────┘
                didDetach                      didDeactivate
```
*/
public enum ActivityState {
    /// Not attached to a superscope.
    /// May start again or be disposed.
    case detached

    /// Not currently doing any work. May start or detach.
    /// Attached to a superscope, but it or an ancestor are detached.
    case attached

    /// Attached to an active scope. May stop or pause.
    /// Has started and is actively performing its behavior.
    case active
}

struct StateTransition: Equatable {
    let previous: ActivityState?
    let current: ActivityState?
}
