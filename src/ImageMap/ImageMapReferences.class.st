"
I am the references of one object, as a small diagram: the object, the classes up its superclass chain, and what its slots point to. Create me with `ImageMapReferences on: anObject`, or press References in the side panel of an ImageMapViewer.

`slots` answers name -> value for the named variables and then the indexed ones (the literals of a compiled method); at most `maxSlots` in all, and `hiddenCount` tells how many are left out. `source` is the Mermaid flowchart, coloured with the kind colours of ImageMapCell. My Diagram view draws it with ImageMapMermaid (Pele2svg is optional); the Slots and Mermaid views work without it.

Only what the object points to is shown. Who points to the object is not (`pointersTo` scans the heap).
"
Class {
	#name : 'ImageMapReferences',
	#superclass : 'Object',
	#instVars : [
		'object',
		'slots',
		'hiddenCount'
	],
	#category : 'ImageMap-Mermaid',
	#package : 'ImageMap',
	#tag : 'Mermaid'
}

{ #category : 'accessing' }
ImageMapReferences class >> maxSlots [
	"At most this many slots are drawn."
	^ 24
]

{ #category : 'instance creation' }
ImageMapReferences class >> on: anObject [
	^ self new setObject: anObject
]

{ #category : 'private' }
ImageMapReferences >> collectSlots [
	| list c limit count shown literals |
	list := OrderedCollection new.
	hiddenCount := 0.
	limit := self class maxSlots.
	[c := object class.
	c allInstVarNames doWithIndex: [:n :i | list add: n -> (object instVarAt: i)].
	literals := (c includesBehavior: CompiledCode) ifTrue: [object literals] ifFalse: [nil].
	count := literals
		ifNotNil: [literals size]
		ifNil: [(c isVariable and: [c isPointers]) ifTrue: [object basicSize] ifFalse: [0]].
	shown := ((limit - list size) max: 0) min: count.
	1 to: shown do: [:i |
		list add: '[', i printString, ']' -> (literals ifNil: [object basicAt: i] ifNotNil: [literals at: i])].
	hiddenCount := count - shown]
		on: Error
		do: [:e | list add: '(error)' -> e messageText].
	^ list
]

{ #category : 'private' }
ImageMapReferences >> escaped: aString [
	"Make aString safe inside a quoted Mermaid label, and short."
	| s |
	s := aString copyReplaceAll: '#' with: '#35;'.
	s := s copyReplaceAll: '"' with: '#quot;'.
	s := s copyReplaceAll: '<' with: '#lt;'.
	s := s copyReplaceAll: '>' with: '#gt;'.
	s := s copyReplaceAll: '&' with: '#amp;'.
	s := s collect: [:ch | ch isSeparator ifTrue: [$ ] ifFalse: [ch]].
	^ s size > 40 ifTrue: [(s first: 39), '...'] ifFalse: [s]
]

{ #category : 'views' }
ImageMapReferences >> gtDiagramFor: aView [
	<gtView>
	^ aView explicit
		title: 'Diagram';
		priority: 1;
		stencil: [ImageMapMermaid elementForSource: self source]
]

{ #category : 'views' }
ImageMapReferences >> gtSlotsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Slots';
		priority: 2;
		items: [self slots];
		column: 'Slot' text: [:a | a key];
		column: 'Class' text: [:a | [a value class name] on: Error do: ['?']];
		column: 'Value' text: [:a | self labelFor: a value]
]

{ #category : 'views' }
ImageMapReferences >> gtSourceFor: aView [
	<gtView>
	^ aView textEditor
		title: 'Mermaid';
		priority: 3;
		text: [self source]
]

{ #category : 'accessing' }
ImageMapReferences >> hiddenCount [
	"How many slots are not in #slots."
	self slots.
	^ hiddenCount
]

{ #category : 'testing' }
ImageMapReferences >> isAtom: anObject [
	"Immediates, nil, booleans, numbers, characters and strings are drawn as their value."
	^ [anObject isImmediateObject
		or: [anObject isNil or: [anObject isNumber or: [anObject isString or: [anObject isCharacter or: [anObject == true or: [anObject == false]]]]]]]
		on: Error do: [false]
]

{ #category : 'private' }
ImageMapReferences >> labelFor: anObject [
	^ [(self isAtom: anObject)
		ifTrue: [anObject printString]
		ifFalse: [(anObject isBehavior)
			ifTrue: [anObject printString]
			ifFalse: [anObject class name]]]
		on: Error do: ['?']
]

{ #category : 'private' }
ImageMapReferences >> nodeFor: anObject ids: ids on: out [
	"Answer the node id of anObject, writing its definition the first time."
	| id open close |
	^ ids at: anObject ifAbsent: [
		id := 'n', ids size printString.
		ids at: anObject put: id.
		(self isAtom: anObject) ifTrue: [open := '(["'. close := '"])'] ifFalse: [open := '["'. close := '"]'].
		out nextPutAll: '  ', id, open, (self escaped: (self labelFor: anObject)), close, ':::', (self styleFor: anObject); lf.
		id]
]

{ #category : 'accessing' }
ImageMapReferences >> object [
	^ object
]

{ #category : 'printing' }
ImageMapReferences >> printOn: aStream [
	aStream nextPutAll: 'ImageMapReferences on: '; nextPutAll: (self labelFor: object)
]

{ #category : 'initialization' }
ImageMapReferences >> setObject: anObject [
	object := anObject
]

{ #category : 'accessing' }
ImageMapReferences >> slots [
	"name -> value, the named variables first and then the indexed ones."
	^ slots ifNil: [slots := self collectSlots]
]

{ #category : 'sources' }
ImageMapReferences >> source [
	"The Mermaid flowchart of the object, its class chain and its slots. Slots that point to the same object share one arrow, labelled with their names."
	| out ids rootId sup prev cid n groups order |
	out := WriteStream on: String new.
	ids := IdentityDictionary new.
	out nextPutAll: 'flowchart LR'; lf.
	ImageMapCell kinds do: [:k |
		out nextPutAll: '  classDef k_', k, ' fill:#', (ImageMapCell colorFor: k) asHexString, ',stroke:#444,color:#111'; lf].
	out nextPutAll: '  classDef imm fill:#fff,stroke:#888,stroke-dasharray:3 3,color:#111'; lf.
	rootId := 'n0'.
	ids at: object put: rootId.
	out nextPutAll: '  n0["', (self escaped: ((self labelFor: object), ' / ', ([ImageMapCell kindOf: object] on: Error do: [#other]), ' / ', ([object sizeInMemory] on: Error do: [0]) printString, ' B')), '"]:::', (self styleFor: object); lf.
	prev := rootId.
	sup := [object class] on: Error do: [nil].
	n := 0.
	[sup notNil and: [n < 12]] whileTrue: [
		cid := self nodeFor: sup ids: ids on: out.
		out nextPutAll: '  ', prev, (n = 0 ifTrue: [' -.->|instance of| '] ifFalse: [' -->|superclass| ']), cid; lf.
		prev := cid.
		sup := sup superclass.
		n := n + 1].
	groups := Dictionary new.
	order := OrderedCollection new.
	self slots do: [:a | | sid |
		sid := self nodeFor: a value ids: ids on: out.
		(groups includesKey: sid) ifFalse: [groups at: sid put: OrderedCollection new. order add: sid].
		(groups at: sid) add: a key].
	order do: [:sid | | names label |
		names := groups at: sid.
		label := (names size > 4
			ifTrue: [(names first: 3), {'+', (names size - 3) printString}]
			ifFalse: [names]) inject: '' into: [:acc :s | acc isEmpty ifTrue: [s] ifFalse: [acc, ' ', s]].
		out nextPutAll: '  ', rootId, ' -->|"', (self escaped: label), '"| ', sid; lf].
	self hiddenCount > 0 ifTrue: [
		out nextPutAll: '  more["... ', self hiddenCount printString, ' more slots"]:::imm'; lf.
		out nextPutAll: '  ', rootId, ' -.-> more'; lf].
	^ out contents
]

{ #category : 'private' }
ImageMapReferences >> styleFor: anObject [
	^ (self isAtom: anObject)
		ifTrue: ['imm']
		ifFalse: ['k_', ([ImageMapCell kindOf: anObject] on: Error do: [#other])]
]
