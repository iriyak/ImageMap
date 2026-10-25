"
I am one object as seen by ImageMapSnapshot: a reference to the object, its index in heap order (the order of SystemNavigation>>allObjectsDo:), its byte offset (the running total of the sizes of the live objects before it; free chunks are not counted), its size in bytes, and its kind.

The kind is a coarse classification of the object's class: class, method, symbol, string, array, methoddict, dictionary, association, ordered, object, bytes, words, weak, context, block, or other. `ImageMapCell kindOfClass:` computes it, and `ImageMapCell colorFor:` gives the colour that every view uses for it. The colours are kept in a class variable; `ImageMapCell resetColors` rebuilds them.
"
Class {
	#name : 'ImageMapCell',
	#superclass : 'Object',
	#instVars : [
		'object',
		'index',
		'offset',
		'bytes',
		'kind'
	],
	#classVars : [
		'Colors'
	],
	#category : 'ImageMap-Core',
	#package : 'ImageMap',
	#tag : 'Core'
}

{ #category : 'colors' }
ImageMapCell class >> colorFor: aKind [
	^ self colors at: aKind ifAbsent: [Color gray]
]

{ #category : 'colors' }
ImageMapCell class >> colors [
	^ Colors ifNil: [Colors := Dictionary newFrom: {
		#class -> (Color fromHexString: '4ECDC4').
		#method -> (Color fromHexString: 'FFB52E').
		#symbol -> (Color fromHexString: 'FFD98A').
		#string -> (Color fromHexString: 'F7A8B0').
		#array -> (Color fromHexString: 'EF5B6B').
		#methoddict -> (Color fromHexString: '8338EC').
		#dictionary -> (Color fromHexString: '3A86FF').
		#association -> (Color fromHexString: 'F15BB5').
		#ordered -> (Color fromHexString: 'B5835A').
		#object -> (Color fromHexString: 'A5D84A').
		#bytes -> (Color fromHexString: '8C9BB0').
		#words -> (Color fromHexString: 'C7E58B').
		#weak -> (Color fromHexString: 'B58CF0').
		#context -> (Color fromHexString: 'E8E8E8').
		#block -> (Color fromHexString: '7FD6F5').
		#other -> (Color fromHexString: 'FFFFFF') }]
]

{ #category : 'classification' }
ImageMapCell class >> kindOf: o [
	^ self kindOfClass: ([o class] on: Error do: [^ #other])
]

{ #category : 'classification' }
ImageMapCell class >> kindOfClass: c [
	(c includesBehavior: CompiledCode) ifTrue: [^ #method].
	(c isMeta or: [c == Metaclass]) ifTrue: [^ #class].
	(c includesBehavior: Symbol) ifTrue: [^ #symbol].
	(c includesBehavior: String) ifTrue: [^ #string].
	(c includesBehavior: Context) ifTrue: [^ #context].
	(c includesBehavior: BlockClosure) ifTrue: [^ #block].
	(c includesBehavior: MethodDictionary) ifTrue: [^ #methoddict].
	(c includesBehavior: Dictionary) ifTrue: [^ #dictionary].
	(c includesBehavior: Association) ifTrue: [^ #association].
	(c includesBehavior: OrderedCollection) ifTrue: [^ #ordered].
	c isWeak ifTrue: [^ #weak].
	c isBytes ifTrue: [^ #bytes].
	c isWords ifTrue: [^ #words].
	c isVariable ifTrue: [^ #array].
	^ #object
]

{ #category : 'accessing' }
ImageMapCell class >> kinds [
	^ #(#class #method #symbol #string #array #methoddict #dictionary #association #ordered #object #bytes #words #weak #context #block #other)
]

{ #category : 'accessing' }
ImageMapCell class >> legendKinds [
	"Kinds shown in the legend (the catch-all #other is left out)."
	^ self kinds reject: [:k | k == #other]
]

{ #category : 'colors' }
ImageMapCell class >> resetColors [
	Colors := nil
]

{ #category : 'formatting' }
ImageMapCell class >> roundedText: aNumber [
	"aNumber with at most two decimals, rounded, without trailing zeros: 10.8, 5, 0.02. It is how the diagrams (Pele2svg) show a value, so the side panels use it too and the numbers agree."
	| s |
	s := aNumber asFloat printShowingDecimalPlaces: 2.
	[s last = $0] whileTrue: [s := s allButLast].
	s last = $. ifTrue: [s := s allButLast].
	^ s
]

{ #category : 'accessing' }
ImageMapCell >> bytes [
	^ bytes
]

{ #category : 'accessing' }
ImageMapCell >> bytes: anObject [
	bytes := anObject
]

{ #category : 'accessing' }
ImageMapCell >> className [
	^ [object class name] on: Error do: ['?']
]

{ #category : 'accessing' }
ImageMapCell >> index [
	^ index
]

{ #category : 'accessing' }
ImageMapCell >> index: anObject [
	index := anObject
]

{ #category : 'accessing' }
ImageMapCell >> kind [
	^ kind
]

{ #category : 'accessing' }
ImageMapCell >> kind: anObject [
	kind := anObject
]

{ #category : 'printing' }
ImageMapCell >> label [
	^ '#', index printString, '  +', (offset printStringBase: 16), '  ', kind, '  ', self className, '  ', bytes printString, ' B'
]

{ #category : 'accessing' }
ImageMapCell >> object [
	^ object
]

{ #category : 'accessing' }
ImageMapCell >> object: anObject [
	object := anObject
]

{ #category : 'accessing' }
ImageMapCell >> offset [
	^ offset
]

{ #category : 'accessing' }
ImageMapCell >> offset: anObject [
	offset := anObject
]

{ #category : 'formatting' }
ImageMapCell >> sizeFormulaTexLines [
	"Two lines of TeX that show how the size follows from the number of slots, with the numbers of this object: the slots w, and then the size s. Answers nil when the size is not that of a plain object (a compiled method, a proxy that does not answer its class) or the rule does not give it. The rule: a header of 8 bytes and 8 bytes for each slot (w), at least 16 bytes, and one more word of 8 bytes when w is 255 or more. Bytes and 32-bit words fill slots of 8 bytes (rounded up). See docs/IMPLEMENTATION.md."

	| c n w size slots |
	c := [ object class ] on: Error do: [ ^ nil ].
	(c includesBehavior: CompiledCode) ifTrue: [ ^ nil ].
	n := c isVariable ifTrue: [ [ object basicSize ] on: Error do: [ ^ nil ] ] ifFalse: [ 0 ].
	c isBytes
		ifTrue: [ w := c instSize + (n + 7 // 8). slots := 'w=\lceil ', n printString, '/8\rceil=', w printString ]
		ifFalse: [ c isWords
			ifTrue: [ w := c instSize + (n * 4 + 7 // 8). slots := 'w=\lceil 4\cdot ', n printString, '/8\rceil=', w printString ]
			ifFalse: [ w := c instSize + n. slots := 'w=', w printString ] ].
	size := 16 max: 8 + (8 * w) + (w >= 255 ifTrue: [ 8 ] ifFalse: [ 0 ]).
	size = bytes ifFalse: [ ^ nil ].
	^ { slots. 's=\max(16,\,8+8w', (w >= 255 ifTrue: [ '+8' ] ifFalse: [ '' ]), ')=', size printString }
]
