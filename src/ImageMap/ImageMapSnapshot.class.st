"
I am a window of consecutive objects, in the order SystemNavigation>>allObjectsDo: visits them: `count` objects from index `start`, each one an ImageMapCell. Create me with `ImageMapSnapshot start: 5000000 count: 1024`, or with `ImageMapSnapshot startingAt: anObject count: 1024` to start at the current index of an object (nil if the object is gone).

`mapElement` draws me as a 16-column block map; click a block to inspect its object. My Map view in the inspector is an ImageMapViewer. Building me walks the heap from the beginning, so it takes about a second when start is around 5,000,000.

Indexes and offsets change when the garbage collector runs, so I am a picture of one moment.

My Classes view draws the bytes of my objects by kind and class as a sankey diagram (the 14 classes with most bytes are named), and Classes (Mermaid) shows its source. `classStats` has the numbers in the same shape as ImageMapOverview>>classStats. The diagram needs Pele2svg.
"
Class {
	#name : 'ImageMapSnapshot',
	#superclass : 'Object',
	#instVars : [
		'cells',
		'start',
		'columns'
	],
	#category : 'ImageMap-Window',
	#package : 'ImageMap',
	#tag : 'Window'
}

{ #category : 'instance creation' }
ImageMapSnapshot class >> start: aStart count: aCount [
	^ self new setStart: aStart count: aCount
]

{ #category : 'instance creation' }
ImageMapSnapshot class >> startingAt: anObject count: aCount [
	"Answer the window that starts at anObject's CURRENT index in heap order, or nil if the object no longer exists."
	| i found |
	i := 0. found := false.
	[:exit | SystemNavigation default allObjectsDo: [:o |
		o == anObject ifTrue: [found := true. exit value].
		i := i + 1]] valueWithExit.
	^ found ifTrue: [self start: i count: aCount] ifFalse: [nil]
]

{ #category : 'accessing' }
ImageMapSnapshot >> cells [
	^ cells
]

{ #category : 'analysis' }
ImageMapSnapshot >> classStats [
	"IdentityDictionary: class -> Array(kind index, bytes, objects) over the cells of this window (the same shape as ImageMapOverview>>classStats)."
	| kinds stats |
	kinds := ImageMapCell kinds.
	stats := IdentityDictionary new.
	cells do: [:cell | | c e |
		c := [cell object class] on: Error do: [Object].
		e := stats at: c ifAbsentPut: [Array with: (kinds indexOf: cell kind) with: 0 with: 0].
		e at: 2 put: (e at: 2) + cell bytes.
		e at: 3 put: (e at: 3) + 1].
	^ stats
]

{ #category : 'accessing' }
ImageMapSnapshot >> columns [
	^ columns ifNil: [16]
]

{ #category : 'accessing' }
ImageMapSnapshot >> count [
	^ cells size
]

{ #category : 'accessing' }
ImageMapSnapshot >> endIndex [
	^ cells isEmpty ifTrue: [start] ifFalse: [cells last index]
]

{ #category : 'accessing' }
ImageMapSnapshot >> endOffset [
	^ cells isEmpty ifTrue: [0] ifFalse: [cells last offset + cells last bytes]
]

{ #category : 'views' }
ImageMapSnapshot >> gtClassesFor: aView [
	<gtView>
	^ aView explicit
		title: 'Classes';
		priority: 2;
		stencil: [ImageMapMermaid classesElementForSnapshot: self]
]

{ #category : 'views' }
ImageMapSnapshot >> gtClassesSourceFor: aView [
	<gtView>
	^ aView textEditor
		title: 'Classes (Mermaid)';
		priority: 3;
		text: [ImageMapMermaid classesSourceForSnapshot: self]
]

{ #category : 'views' }
ImageMapSnapshot >> gtMapFor: aView [
	<gtView>
	^ aView explicit
		title: 'Map';
		priority: 1;
		stencil: [(ImageMapViewer on: self) element]
]

{ #category : 'analysis' }
ImageMapSnapshot >> kindStats [
	"Answer an Array of kind -> (Array bytes objects) for this window, the kinds with most bytes first. A kind with no bytes is left out."
	| sums |
	sums := Dictionary new.
	cells do: [:c | | e |
		e := sums at: c kind ifAbsentPut: [Array with: 0 with: 0].
		e at: 1 put: (e at: 1) + c bytes.
		e at: 2 put: (e at: 2) + 1].
	^ ((sums associations select: [:a | a value first > 0])
		asSortedCollection: [:a :b | a value first > b value first or: [a value first = b value first and: [a key <= b key]]]) asArray
]

{ #category : 'ui' }
ImageMapSnapshot >> legendElement [
	| row |
	row := BlElement new
		layout: BlFlowLayout horizontal;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent];
		padding: (BlInsets all: 6).
	ImageMapCell legendKinds do: [:k | | item sq |
		sq := BlElement new size: 12 @ 12; background: (ImageMapCell colorFor: k);
			geometry: (BlRoundedRectangleGeometry cornerRadius: 2);
			margin: (BlInsets top: 4 left: 0 bottom: 0 right: 4).
		item := BlElement new
			layout: BlLinearLayout horizontal;
			constraintsDo: [:c | c horizontal fitContent. c vertical fitContent];
			margin: (BlInsets right: 12).
		item addChild: sq.
		item addChild: (BrLabel new aptitude: BrGlamorousLabelAptitude; text: k asString).
		row addChild: item].
	^ row
]

{ #category : 'ui' }
ImageMapSnapshot >> mapElement [
	^ self mapElementOnSelect: [:cell :el | el phlow spawnObject: cell object]
]

{ #category : 'ui' }
ImageMapSnapshot >> mapElementOnSelect: aBlock [
	| pitch cellSize labelWidth rows root |
	pitch := 14. cellSize := 12. labelWidth := 84.
	rows := (cells size / self columns) ceiling.
	root := BlElement new
		size: (labelWidth + (self columns * pitch) + 8) @ (rows * pitch + 8);
		background: (Color fromHexString: '1B2230').
	cells doWithIndex: [:cell :n | | col row el |
		col := (n - 1) \\ self columns.
		row := (n - 1) // self columns.
		el := BlElement new
			size: cellSize @ cellSize;
			relocate: (labelWidth + (col * pitch)) @ (row * pitch + 4);
			background: (ImageMapCell colorFor: cell kind);
			geometry: (BlRoundedRectangleGeometry cornerRadius: 2).
		el addAptitude: (BrGlamorousWithTooltipAptitude content: [
			BrLabel new aptitude: BrGlamorousLabelAptitude; text: cell label]).
		el when: BlClickEvent do: [:evt | aBlock value: cell value: evt currentTarget].
		root addChild: el].
	0 to: rows - 1 do: [:r | | first t |
		first := cells at: r * self columns + 1.
		t := (first offset printStringBase: 16) asUppercase asRopedText.
		t foreground: (Color fromHexString: '8A94A6'); fontSize: 10.
		root addChild: (BlTextElement new text: t; relocate: 4 @ (r * 14 + 3))].
	^ root
]

{ #category : 'printing' }
ImageMapSnapshot >> printOn: aStream [
	aStream
		nextPutAll: 'ImageMap #'; print: start; nextPutAll: '..#'; print: self endIndex;
		nextPutAll: ' (+'; nextPutAll: (self startOffset printStringBase: 16);
		nextPutAll: '..+'; nextPutAll: (self endOffset printStringBase: 16); nextPut: $)
]

{ #category : 'private' }
ImageMapSnapshot >> scanTo: anEnd slow: aBoolean [
	"Walk objects in heap order up to index anEnd, accumulating byte offsets; answer cells for indexes >= start.
	The fast path has no per-object exception handler (it is ~20x faster); the slow path guards each object.
	Objects that answer something other than an Integer to sizeInMemory (proxies with their own doesNotUnderstand:) are sized from their class."
	| i off list |
	list := OrderedCollection new: anEnd - start.
	i := 0. off := 0.
	SystemNavigation default allObjectsDo: [:o | | sz |
		i >= anEnd ifTrue: [^ list asArray].
		sz := aBoolean
			ifTrue: [[o sizeInMemory] on: Error do: [16]]
			ifFalse: [o sizeInMemory].
		sz isInteger ifFalse: [sz := 16].
		i >= start ifTrue: [
			list add: (ImageMapCell new
				object: o; index: i; offset: off; bytes: sz;
				kind: (ImageMapCell kindOf: o); yourself)].
		off := off + sz.
		i := i + 1].
	^ list asArray
]

{ #category : 'initialization' }
ImageMapSnapshot >> setStart: aStart count: aCount [
	start := aStart.
	cells := [self scanTo: aStart + aCount slow: false]
		on: Error do: [:e | self scanTo: aStart + aCount slow: true]
]

{ #category : 'accessing' }
ImageMapSnapshot >> start [
	^ start
]

{ #category : 'accessing' }
ImageMapSnapshot >> startOffset [
	^ cells isEmpty ifTrue: [0] ifFalse: [cells first offset]
]

{ #category : 'analysis' }
ImageMapSnapshot >> totalBytes [
	"The bytes of the objects in this window."
	^ cells inject: 0 into: [:sum :cell | sum + cell bytes]
]
