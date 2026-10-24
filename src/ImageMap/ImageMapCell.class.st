"
One heap object seen by the image map: a reference to the object, its index in heap order (allObjectsDo: order), its cumulative byte offset (live objects only, free chunks not counted), its size in bytes and a coarse kind.
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
	#category : 'ImageMap',
	#package : 'ImageMap'
}

{ #category : 'as yet unclassified' }
ImageMapCell class >> colorFor: aKind [
	^ self colors at: aKind ifAbsent: [Color gray]
]

{ #category : 'as yet unclassified' }
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

{ #category : 'as yet unclassified' }
ImageMapCell class >> kindOf: o [
	^ self kindOfClass: ([o class] on: Error do: [^ #other])
]

{ #category : 'as yet unclassified' }
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

{ #category : 'as yet unclassified' }
ImageMapCell class >> kinds [
	^ #(#class #method #symbol #string #array #methoddict #dictionary #association #ordered #object #bytes #words #weak #context #block #other)
]

{ #category : 'as yet unclassified' }
ImageMapCell class >> legendKinds [
	"Kinds shown in the legend (the catch-all #other is left out)."
	^ self kinds reject: [:k | k == #other]
]

{ #category : 'as yet unclassified' }
ImageMapCell class >> resetColors [
	Colors := nil
]

{ #category : 'as yet unclassified' }
ImageMapCell >> bytes [
	^ bytes
]

{ #category : 'as yet unclassified' }
ImageMapCell >> bytes: anObject [
	bytes := anObject
]

{ #category : 'as yet unclassified' }
ImageMapCell >> className [
	^ [object class name] on: Error do: ['?']
]

{ #category : 'as yet unclassified' }
ImageMapCell >> index [
	^ index
]

{ #category : 'as yet unclassified' }
ImageMapCell >> index: anObject [
	index := anObject
]

{ #category : 'as yet unclassified' }
ImageMapCell >> kind [
	^ kind
]

{ #category : 'as yet unclassified' }
ImageMapCell >> kind: anObject [
	kind := anObject
]

{ #category : 'as yet unclassified' }
ImageMapCell >> label [
	^ '#', index printString, '  +', (offset printStringBase: 16), '  ', kind, '  ', self className, '  ', bytes printString, ' B'
]

{ #category : 'as yet unclassified' }
ImageMapCell >> object [
	^ object
]

{ #category : 'as yet unclassified' }
ImageMapCell >> object: anObject [
	object := anObject
]

{ #category : 'as yet unclassified' }
ImageMapCell >> offset [
	^ offset
]

{ #category : 'as yet unclassified' }
ImageMapCell >> offset: anObject [
	offset := anObject
]
