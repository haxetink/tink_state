# Tinkerbell Reactive State Handling

Dealing with mutable state is a tricky business, which very often results in some parts of your application having stale data, leading to poor UX at best and outright incorrect behavior at worst. There are many attempts to overcome the issue, and tink_state is one of them. In a nutshell tink_state provides:

- observable data structures (i.e. changes to those data structures can be subscribed to)
- the means to derive live-computed data from those (i.e. changes to the source data will update the derived data)
- bindings that efficiently propagate changed data to code that will perform appropriate updates

For a short intro, you may wish to check out the [crash course](crash-course.md).

## Similar libraries

The main inspiration for tink_state was the dependency tracking from [Knockout.js](https://knockoutjs.com/index.html), which has since been replicated in many other libraries and frameworks, in particular in the JavaScript ecosystem. The most notable examples are [MobX](https://mobx.js.org/README.html) and [Vue.js](https://vuejs.org/).

## Caveats

If you're modifying data that is not backed by tink_state's observable data structures (i.e. `State`, `ObservableArray` or `ObservableMap`), tink_state will not be able to detect the changes (unless you're familiar enough with the implementation to ensure this otherwise). It will thus not update values or trigger bindings. For things to work correctly, all data must either be immutable, or observable (i.e. mutations may only be performed on `State`, `ObservableArray` or `ObservableMap`). Ensuring this is your responsibility. You may be interested in [coconut.data](https://github.com/MVCoconut/coconut.data/) which attempts to statically ensure you only use immutable or observable data types.