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
