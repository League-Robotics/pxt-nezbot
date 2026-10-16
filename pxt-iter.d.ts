// Editor-only. PXT compiles without a standard library and lets for...of
// run over arrays and strings; these declarations let the editor accept that
// too. Not listed in pxt.json, so the micro:bit build never sees it.
interface SymbolConstructor { readonly iterator: symbol; }
declare var Symbol: SymbolConstructor;
interface IteratorResult<T> { done: boolean; value: T; }
interface Iterator<T> { next(): IteratorResult<T>; }
interface Iterable<T> { [Symbol.iterator](): Iterator<T>; }
interface Array<T> { [Symbol.iterator](): Iterator<T>; }
interface String { [Symbol.iterator](): Iterator<string>; }
