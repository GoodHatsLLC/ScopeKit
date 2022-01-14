# ScopeKit
ScopeKit is a Swift library for managing the lifecycle of Combine subscriptions.

## Purpose
Ensuring that code *can* only run at the right time is critical to stability and security but managing application state is hard. Apple's Combine is a great way write clear, testable, logic but managing the subscription lifecycle is fiddly.

Combine code is often written assuming that object lifecycles can control subscription lifecycles. But this involves error-prone weakification (i.e. the need to use incantations like `.sink { [weak self] in guard let self = self else { return }`) and leaves a lot of other management to be done manually ('how do i restart this?').

ScopeKit allows you to build out a tree of 'scopes' as a scaffold within your app. Subscriptions are bound to their owning Scope and their lifecycles managed automatically (with no need for `[weak self]` incantations), and according to simpele and predictable rules.


## Usage
1. Add `ScopeKit` to your SPM dependencies. `https://github.com/GoodHatsLLC/ScopeKit.git`
2. `import ScopeKit`
3. Build out a tree of `Scopes` and `Behaviors` under your `RootScope` :)

## Concepts

ScopeKit's core components are the `Scope` and `Behavior` superclasses. Both have the following lifecycle, and can only perform work while `active`.

### Activity Lifecycle

```
 ┌────────────┐  willAttach   ┌────────────┐ willActivate ┌────────────┐
 │  Detached  │──────────────▶│  Attached  │─────────────▶│   Active   │
 └────────────┘               └────────────┘              └────────────┘
        ▲                         │    ▲                        │
        │                         │    │                        │
        └─────────────────────────┘    └────────────────────────┘
                didDetach                      didDeactivate
```

You can create a `Behavior` or `Scope` by inheriting from their respective superclasses. In the following example any subscription created in `willActivate` and stored in the provided `cancellables` will be cancelled when `MyBehavior` is no longer `active`. It is restarted if the `Behavior`
once again becomes `active`.

`Scopes` have the exact same lifecycle as `Behaviors`.

```swift
final class MyBehavior: Behavior {

    override func willAttach() {}

    override func willActivate(cancellables: inout Set<AnyCancellable>) {
        /*
         myPublisher
            .sink {
                // Work that is scoped to the behavior's active state
            }
            .store(in: &cancellables)
         */
    }

    override func didDeactivate() {}

    override func didDetach() {}

}
```

### Scopes & Behaviors

`Scopes` differ from `Behaviors` in that they can contain other `Scopes` or `Behaviors`. A `Behavior` is node of work. A `Scope` can be a tree.

`Scopes` and `Behaviors` can be attached to host-scopes using their `attach(to:)` methods and detached using `detach()`. (You can also use the host's `host(_:)` and `evict(_:)` respectively, passing the scope to be hosted.)

A `Scope` can also bind arbitrary subscriptions to its active lifecycle via a `CancellableReceiver` vended on `whileActiveReceiver`.

### Attachment and activity

`Scopes` and `Behaviors` are `active` when they are attached to a host-`Scope` which is *also* active. When their host-`Scope` is not `.active` they are `.attached` and if they have no host-scope they are `.detached`.

| No host       | Inactive host  | Active Host   |
| ------------- | ---------      | ------------  |
| `.detached`   | `.attached`    | `.active`     |
| not working   | not working    | doing work    |

The only exception to this rule is the `RootScope` class, which is always `.active` and can not have a host.

As such it's possible to build out a tree with a `RootScope` at the root, `Scopes` as intermediate nodes, and both `Scopes` and `Behaviors` as leaf nodes. Anything attached to this tree has is `.active` and doing work.

### Using lifecycle event 

The lifecycle events, `willAttach()`, `willActivate(cancellables:)`, `didDeativate()`, and `didDetach()` should be overriden in subclasses and are called by the library. They shouldn't be called directly. Subclasses do not have to call the various `super` methods.

#### willActivate(cancellables:)
`willActivate(cancellables:)` is the primary lifecycle event. Often no other override is needed as `cancel()` is called on the `cancellables` by the library.

#### willAttach()
`willAttach()` *may* be useful if there are linkages between the work the `Scopes` are doing that don't need to be torn down on deactivation, and can wait until full detachment. For example, if a host `Scope` that often toggles between activity and inactivity owns a `UIViewController` a sub-`Scope` could attach a contained ViewController in `willAttach()` once, rather than repeatedly in `willActivate(cancellables:)`.

#### willDetach()
`willDetach()` exists to allow the subclass to cleaning up any state it set up in `willAttach()`.

#### willDeactivate()
`willDeactivate()` is unnecessary as long as the state setup and work started in `willActivate(cancellables:)` can be attached to the passed `cancellables`. i.e. as long as it is a Combine subscription. However, if imperative state setup is done in `willActivate(cancellables:)` it can be torn down here.

### Other Constructs

In addition to `Scope`, `Behavior`, ScopeKit contains:

### RootScope
A non-subclassable, always `active`, root for a `Scope` tree.
```swift
let leafScope = MyLeafScope()
// leafScope is .detached

let middleScope = MyMiddleScope()
leafScope.attach(to: middleScope)
// leafScope is now .attached — but not .active

let rootScope = RootScope()
middleScope.attach(to: rootScope)
// leafScope is now .active and has started its work.
```

### AnonymousBehavior
A convenience `Behavior` which isn't subclassed but whose `willActivate(cancellables:)` behavior is passed in in the initializer.

```swift
AnonymousBehavior { cancellables in
    somePublisher
        .sink { value in
            print(value)
        }
        .store(in: cancellables)
}
```
### CancellableReceiver
A utility on `Scope` which stores `cancellables` to bind subscriptions to its current activity lifecycle. 
```swift
somePublisher
    .sink { _ in
        print("this print can only happen as long as myScope is .active.")
    }
    .store(in: myScope.whileActiveReceiver)

```

## Example App

This repo contains an [example app](https://github.com/GoodHatsLLC/ScopeKit/tree/main/ExampleApp).

The Xcode projects for the example app are built using [Tuist](https://github.com/tuist/tuist).
```bash
cd ExampleApp
tuist dependencies fetch # fetches the in-repo ScopeKit SPM package
tuist generate # generate a project and workspace
open ExampleApp.xcworkspace
```

## State of Project

`ScopeKit` is new, but should now have a stable API. It's reasonably complicated and is commensurately reasonably tested.

Take it for a spin! Comments/Questions/Contributions are super welcome.
