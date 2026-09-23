---
layout: default
---

# Demo.MyLeanFile

### `MyLeanModule.MyLeanFunction`

*def*

```lean
MyLeanModule.MyLeanFunction : Nat → Nat
```

Doubles a natural number.

For example, `MyLeanFunction 3 = 6`. This is a deliberately simple
example: LeanDoc should be able to extract its name, its type
(`Nat → Nat`), and this docstring without any special-casing. 

[source](https://github.com/JVerstry/LeanDoc/blob/1dcbe9696cf9b4240b1b7667b67c7ed7bfed28ea/demo/Demo/MyLeanFile.lean#L22-L28)

### `MyLeanModule.MyLeanTheorem`

*theorem*

```lean
MyLeanModule.MyLeanTheorem : ∀ (n : Nat), MyLeanModule.MyLeanFunction n = n + n
```

`MyLeanFunction` doubles its input.

A minimal example theorem, proved by `rfl` since doubling is definitional
here. LeanDoc should extract this alongside `MyLeanFunction` even though
one is a `def` and the other a `theorem` — both are declarations with a
name, a type, and (optionally) a docstring. 

[source](https://github.com/JVerstry/LeanDoc/blob/1dcbe9696cf9b4240b1b7667b67c7ed7bfed28ea/demo/Demo/MyLeanFile.lean#L30-L37)

### `MyLeanModule.MyLeanStructure`

*structure*

```lean
MyLeanModule.MyLeanStructure : Type
```

A pair of natural numbers, used to demonstrate that LeanDoc also sees
structures and their fields, not just `def`/`theorem`. 

[source](https://github.com/JVerstry/LeanDoc/blob/1dcbe9696cf9b4240b1b7667b67c7ed7bfed28ea/demo/Demo/MyLeanFile.lean#L39-L45)

### `MyLeanModule.MyLeanStructure.mk`

*constructor*

```lean
MyLeanModule.MyLeanStructure.mk : Nat → Nat → MyLeanModule.MyLeanStructure
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/1dcbe9696cf9b4240b1b7667b67c7ed7bfed28ea/demo/Demo/MyLeanFile.lean#L41-L41)

### `MyLeanModule.MyLeanStructure.fst`

*def*

```lean
MyLeanModule.MyLeanStructure.fst : MyLeanModule.MyLeanStructure → Nat
```

The first component. 

[source](https://github.com/JVerstry/LeanDoc/blob/1dcbe9696cf9b4240b1b7667b67c7ed7bfed28ea/demo/Demo/MyLeanFile.lean#L43-L43)

### `MyLeanModule.MyLeanStructure.snd`

*def*

```lean
MyLeanModule.MyLeanStructure.snd : MyLeanModule.MyLeanStructure → Nat
```

The second component. 

[source](https://github.com/JVerstry/LeanDoc/blob/1dcbe9696cf9b4240b1b7667b67c7ed7bfed28ea/demo/Demo/MyLeanFile.lean#L45-L45)

### `MyLeanModule.myLeanUndocumentedFunction`

*def*

```lean
MyLeanModule.myLeanUndocumentedFunction : Nat → Nat
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/1dcbe9696cf9b4240b1b7667b67c7ed7bfed28ea/demo/Demo/MyLeanFile.lean#L49-L50)

### `MyLeanModule.MyLeanProp`

*structure*

```lean
MyLeanModule.MyLeanProp : Prop
```

A `Prop`-valued structure. Originally added to exercise task
T41/T42's Prop-projection noise exclusion (`isNoise`) — but empirically
this simple, single-field case elaborates its projection
(`MyLeanProp.trivial`) as a genuine `theorem` directly, not the `def`
Batteries' own comment describes, so that exclusion never actually
fires here. Kept anyway as a real `Prop`-structure example; see
`isNoise`'s doc comment in `LeanDoc/Core.lean` for the honest status of
that check. 

[source](https://github.com/JVerstry/LeanDoc/blob/1dcbe9696cf9b4240b1b7667b67c7ed7bfed28ea/demo/Demo/MyLeanFile.lean#L60-L70)

### `MyLeanModule.MyLeanProp.mk`

*constructor*

```lean
MyLeanModule.MyLeanProp.mk : True → MyLeanModule.MyLeanProp
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/1dcbe9696cf9b4240b1b7667b67c7ed7bfed28ea/demo/Demo/MyLeanFile.lean#L68-L68)

### `MyLeanModule.MyLeanProp.trivial`

*theorem*

```lean
MyLeanModule.MyLeanProp.trivial : MyLeanModule.MyLeanProp → True
```

Always true. 

[source](https://github.com/JVerstry/LeanDoc/blob/1dcbe9696cf9b4240b1b7667b67c7ed7bfed28ea/demo/Demo/MyLeanFile.lean#L70-L70)
