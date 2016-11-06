package tink.state;

using tink.CoreApi;

enum Promised<T> {
  Loading;
  Done(result:T);
  Failed(error:Error);
}