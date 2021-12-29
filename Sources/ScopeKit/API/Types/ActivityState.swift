import Foundation


/**
 ```
           willStart
        ┌──────◌──────────────────────────────────────┐
        │                                             │
        │                                             ▼
 ┌────────────┐              willUnpause       ┌────────────┐
 │  inactive  │           ┌──────◌────────────▶│   active   │─┐
 └────────────┘           │                    └────────────┘ │
        ▲                 │                           │       │
        │          ┌────────────┐          didPause   │       │
        │          │   paused   │◀────────────◌───────┘       │
        │          └────────────┘                             │
        │                 │                                   │
        │                 │                                   │
        │                 ▼                                   │
        └─────────────────◌───────────────────────────────────┘
                       didStop
```
**/
public enum ActivityState {
    /// Attached to an active scope. May stop or pause.
    /// Has started and is actively performing its behavior.
    case active
    /// Not currently doing any work. May unpause or stop.
    /// Attached to a superscope, but it or an ancestor are detached.
    case paused
    /// Not attached to a superscope.
    /// May start again or be disposed.
    case inactive
}
