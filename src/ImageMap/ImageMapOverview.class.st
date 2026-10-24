"
Whole-heap overview: one pass over all objects (heap order), aggregated into pages of pageBytes live bytes. One block per page, coloured by the kind that takes the most bytes.
"
Class {
	#name : 'ImageMapOverview',
	#superclass : 'Object',
	#instVars : [
		'pages',
		'pageBytes',
		'total',
		'totalBytes',
		'detailBox',
		'selectedElement',
		'selectedPage',
		'classStats',
		'scannedAt'
	],
	#category : 'ImageMap',
	#package : 'ImageMap'
}

{ #category : 'as yet unclassified' }
ImageMapOverview class >> open [
	"Scan, then open the inspector in the UI process (safe to call from any process)."
	| anOverview |
	anOverview := self scan.
	UIManager default defer: [anOverview inspect].
	^ anOverview
]

{ #category : 'as yet unclassified' }
ImageMapOverview class >> scan [
	^ self scanPageBytes: 1048576
]

{ #category : 'as yet unclassified' }
ImageMapOverview class >> scanPageBytes: aSize [
	"Collect garbage first so the picture shows live objects only."
	Smalltalk garbageCollect.
	^ [self new scanPageBytes: aSize slow: false]
		on: Error do: [:e | self new scanPageBytes: aSize slow: true]
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> baselineSection [
	| box status setBtn cmpBtn row |
	box := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent].
	box addChild: (self heading: 'Baseline (for diff)').
	status := self line: 'baseline: ', ImageMapDiff baselineDescription.
	box addChild: status.
	row := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent];
		margin: (BlInsets top: 6 left: 0 bottom: 0 right: 0).
	setBtn := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Set as baseline';
		margin: (BlInsets right: 8).
	setBtn action: [
		ImageMapDiff baseline: self.
		status text: 'baseline: ', ImageMapDiff baselineDescription].
	cmpBtn := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Compare with now'.
	cmpBtn action: [
		ImageMapDiff baseline
			ifNil: [status text: 'no baseline yet: press Set as baseline first']
			ifNotNil: [cmpBtn phlow spawnObject: ImageMapDiff compareToBaseline]].
	row addChild: setBtn; addChild: cmpBtn.
	box addChild: row.
	^ box
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> classStats [
	"IdentityDictionary: class -> Array(kind index, bytes, object count), as of the scan."
	^ classStats
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> element [
	| root body mapHolder scroll |
	selectedElement := nil.
	selectedPage := nil.
	root := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	root addChild: ImageMapSnapshot new legendElement.
	root addChild: ((self line: 'One block = ', (self mebibytes: pageBytes), ' of live objects in heap order; colour = the kind with the most bytes.')
		margin: (BlInsets left: 6); yourself).
	body := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	mapHolder := BlElement new
		constraintsDo: [:c | c horizontal exact: 470. c vertical matchParent].
	scroll := (self mapElementOnSelect: [:aPage :el | self select: aPage element: el]) asScrollableElement.
	scroll constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	mapHolder addChild: scroll.
	body addChild: mapHolder; addChild: self sideElement.
	root addChild: body.
	^ root
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> gtMapFor: aView [
	<gtView>
	^ aView explicit
		title: 'Map';
		priority: 1;
		stencil: [self element]
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> heading: aString [
	^ ImageMapViewer new heading: aString
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> kindBytesRow: aKind bytes: b [
	| row sq |
	row := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent].
	sq := BlElement new
		size: 12 @ 12;
		background: (ImageMapCell colorFor: aKind);
		geometry: (BlRoundedRectangleGeometry cornerRadius: 2);
		margin: (BlInsets top: 4 left: 0 bottom: 0 right: 6).
	row addChild: sq.
	row addChild: (self line: aKind asString, '  ', (self mebibytes: b), '  (', (b * 100 // (totalBytes max: 1)) printString, '%)').
	^ row
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> kindTotals [
	"Answer kind -> total bytes over all pages, biggest first."
	| sums |
	sums := Array new: ImageMapCell kinds size withAll: 0.
	pages do: [:p | 1 to: sums size do: [:i | sums at: i put: (sums at: i) + (p byKind at: i)]].
	^ ((1 to: sums size) collect: [:i | (ImageMapCell kinds at: i) -> (sums at: i)])
		asSortedCollection: [:a :b | a value >= b value]
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> line: aString [
	^ ImageMapViewer new line: aString
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> mapElementOnSelect: aBlock [
	| pitch cellSize labelWidth cols rows root |
	pitch := 22. cellSize := 20. labelWidth := 84. cols := 16.
	rows := (pages size / cols) ceiling.
	root := BlElement new
		size: (labelWidth + (cols * pitch) + 8) @ (rows * pitch + 8);
		background: (Color fromHexString: '1B2230').
	pages doWithIndex: [:page :n | | col row el |
		col := (n - 1) \\ cols.
		row := (n - 1) // cols.
		el := BlElement new
			size: cellSize @ cellSize;
			relocate: (labelWidth + (col * pitch)) @ (row * pitch + 4);
			background: (ImageMapCell colorFor: page dominantKind);
			geometry: (BlRoundedRectangleGeometry cornerRadius: 3).
		el addAptitude: (BrGlamorousWithTooltipAptitude content: [
			BrLabel new aptitude: BrGlamorousLabelAptitude; text: page label]).
		el when: BlClickEvent do: [:evt | aBlock value: page value: evt currentTarget].
		root addChild: el].
	0 to: rows - 1 do: [:r | | first t |
		first := pages at: r * cols + 1.
		t := (first offset printStringBase: 16) asUppercase asRopedText.
		t foreground: (Color fromHexString: '8A94A6'); fontSize: 10.
		root addChild: (BlTextElement new text: t; relocate: 4 @ (r * pitch + 6))].
	^ root
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> mebibytes: bytes [
	^ ((bytes * 10 // 1048576) / 10.0) printString, ' MiB'
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> pageBytes [
	^ pageBytes
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> pages [
	^ pages
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> printOn: aStream [
	aStream nextPutAll: 'ImageMapOverview '; print: total; nextPutAll: ' objects, '; print: totalBytes // 1048576; nextPutAll: ' MiB, '; print: pages size; nextPutAll: ' pages'
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> refreshDetail [
	| btn pg |
	detailBox removeChildren.
	selectedPage ifNil: [detailBox addChild: (self line: 'Click a block.'). ^ self].
	pg := selectedPage.
	{ 'offset: +', (pg offset printStringBase: 16).
	  'objects: ', pg objectCount printString.
	  'size: ', (pg bytes // 1024) printString, ' KiB'.
	  'first object: #', pg firstIndex printString, ' (at scan time)' }
		do: [:s | detailBox addChild: (self line: s)].
	(pg topKinds: 4) do: [:a |
		detailBox addChild: (self line: '  ', a key asString, '  ', (a value // 1024) printString, ' KiB  (', (a value * 100 // (pg bytes max: 1)) printString, '%)')].
	btn := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Open window here';
		margin: (BlInsets top: 8 left: 0 bottom: 0 right: 0).
	btn action: [ | w |
		w := pg isAnchorAlive
			ifTrue: [ImageMapSnapshot startingAt: pg firstObject count: 1024]
			ifFalse: [nil].
		w ifNil: [detailBox addChild: (self line: 'That object no longer exists (GC). Rescan the overview.')]
			ifNotNil: [btn phlow spawnObject: (ImageMapViewer on: w)]].
	detailBox addChild: btn
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> scanPageBytes: aSize slow: aBoolean [
	| kinds cache i off nextBoundary cur |
	kinds := ImageMapCell kinds.
	cache := IdentityDictionary new.
	pageBytes := aSize.
	pages := OrderedCollection new.
	scannedAt := DateAndTime now.
	i := 0. off := 0. nextBoundary := 0.
	SystemNavigation default allObjectsDo: [:o | | c e k sz |
		c := aBoolean ifTrue: [[o class] on: Error do: [Object]] ifFalse: [o class].
		e := cache at: c ifAbsent: [nil].
		e ifNil: [e := cache at: c put: (Array with: (kinds indexOf: (ImageMapCell kindOfClass: c)) with: 0 with: 0)].
		k := e first.
		sz := aBoolean ifTrue: [[o sizeInMemory] on: Error do: [16]] ifFalse: [o sizeInMemory].
		sz isInteger ifFalse: [sz := c isVariable ifTrue: [16] ifFalse: [c byteSizeOfInstance]].
		off >= nextBoundary ifTrue: [
			cur := ImageMapPage new setFirstObject: o index: i offset: off kinds: kinds size.
			pages add: cur.
			nextBoundary := (off // aSize + 1) * aSize].
		cur addObject: sz kind: k.
		e at: 2 put: (e at: 2) + sz.
		e at: 3 put: (e at: 3) + 1.
		off := off + sz.
		i := i + 1].
	total := i.
	totalBytes := off.
	pages := pages asArray.
	classStats := cache
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> scannedAt [
	^ scannedAt
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> select: aPage element: anElement [
	selectedElement ifNotNil: [:prev | prev border: BlBorder empty].
	selectedElement := anElement.
	selectedPage := aPage.
	anElement border: (BlBorder paint: Color white width: 2).
	self refreshDetail
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> sideElement [
	| side |
	side := BlElement new
		layout: BlLinearLayout vertical;
		padding: (BlInsets all: 8);
		constraintsDo: [:c | c horizontal exact: 300. c vertical matchParent].
	side addChild: (self heading: 'Heap').
	side addChild: (self line: total printString, ' objects').
	side addChild: (self line: (self mebibytes: totalBytes), ' of live objects').
	side addChild: (self line: pages size printString, ' blocks x ', (self mebibytes: pageBytes)).
	side addChild: self baselineSection.
	side addChild: (self heading: 'Bytes by kind').
	self kindTotals do: [:a | a value > 0 ifTrue: [side addChild: (self kindBytesRow: a key bytes: a value)]].
	side addChild: (self heading: 'Selected block').
	detailBox := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent].
	side addChild: detailBox.
	self refreshDetail.
	^ side
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> total [
	^ total
]

{ #category : 'as yet unclassified' }
ImageMapOverview >> totalBytes [
	^ totalBytes
]
