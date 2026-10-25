"
I am a picture of the whole heap. One pass over all objects, in the order SystemNavigation>>allObjectsDo: visits them, is cut into pages (ImageMapPage) of about 1 MiB of live objects. I draw one block per page, 16 per row, coloured by the kind that takes the most bytes in the page. My side panel shows the bytes per kind for the whole heap, a Classes button that opens my Classes view, the baseline buttons, and the details of the selected page, with Open window here to open an ImageMapViewer at the start of that page.

`ImageMapOverview scan` collects garbage and then scans (a few seconds for about 8 million objects). `ImageMapOverview open` does that and opens me in the UI process. `scanPageBytes:` uses another page size, but only 1 MiB (`defaultPageBytes`) has been tried in the views. I also keep the bytes and the object count per class (`classStats`), which ImageMapDiff needs.

Set as baseline keeps me as the baseline for ImageMapDiff, and Compare with now opens the diff.

The same pass counts which kind follows which in heap order (`transitions`) and how many objects and bytes each kind has in each size class (`sizeCounts`, `sizeBytes`). My diagram views are Classes (a sankey of bytes per kind and class), Neighbours and Sizes, each with a table or the Mermaid source next to it. They are built by ImageMapMermaid and need Pele2svg for the drawing; the numbers are in `kindTransitionRows` and `sizeClassRows`.
"
Class {
	#name : 'ImageMapOverview',
	#superclass : 'Object',
	#instVars : [
		'pages',
		'pageBytes',
		'total',
		'totalBytes',
		'classStats',
		'scannedAt',
		'transitions',
		'sizeCounts',
		'sizeBytes'
	],
	#category : 'ImageMap-Overview',
	#package : 'ImageMap',
	#tag : 'Overview'
}

{ #category : 'accessing' }
ImageMapOverview class >> defaultPageBytes [
	"The size of a page of the overview: 1 MiB of live objects, as a rule. It is a size that keeps the number of blocks readable on a heap of a few hundred MiB; only this size has been tried in the views."
	^ 1024 * 1024
]

{ #category : 'opening' }
ImageMapOverview class >> open [
	"Scan, then open the inspector in the UI process (safe to call from any process)."
	| anOverview |
	anOverview := self scan.
	UIManager default defer: [anOverview inspect].
	^ anOverview
]

{ #category : 'instance creation' }
ImageMapOverview class >> scan [
	^ self scanPageBytes: self defaultPageBytes
]

{ #category : 'instance creation' }
ImageMapOverview class >> scanPageBytes: aSize [
	"Collect garbage first so the picture shows live objects only."
	Smalltalk garbageCollect.
	^ [self new scanPageBytes: aSize slow: false]
		on: Error do: [:e | self new scanPageBytes: aSize slow: true]
]

{ #category : 'analysis' }
ImageMapOverview class >> sizeClassCount [
	"Size classes are powers of two: class n holds the sizes above 2^(n-1) and up to 2^n bytes, counted from 1 (up to 1 B) to 40 (up to 512 GiB)."
	^ 40
]

{ #category : 'analysis' }
ImageMapOverview class >> sizeClassLabel: n [
	"The upper bound of size class n, as text."
	| bound |
	bound := 1 bitShift: n - 1.
	^ bound < 1024
		ifTrue: ['<= ', bound printString, ' B']
		ifFalse: [bound < 1048576
			ifTrue: ['<= ', (bound // 1024) printString, ' KiB']
			ifFalse: ['<= ', (bound // 1048576) printString, ' MiB']]
]

{ #category : 'analysis' }
ImageMapOverview class >> sizeClassOf: aSize [
	"The number of the size class of aSize bytes (see sizeClassCount)."
	^ (((aSize - 1) max: 0) highBit + 1) min: self sizeClassCount
]

{ #category : 'analysis' }
ImageMapOverview class >> sizeClassShortLabel: n [
	"The upper bound of size class n in a few characters: 16, 512, 1K, 2M."
	| bound |
	bound := 1 bitShift: n - 1.
	^ bound < 1024
		ifTrue: [bound printString]
		ifFalse: [bound < 1048576
			ifTrue: [(bound // 1024) printString, 'K']
			ifFalse: [(bound // 1048576) printString, 'M']]
]

{ #category : 'ui' }
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
			ifNotNil: [cmpBtn phlow spawnObject: ImageMapDiff compareToBaseline viewName: 'Map']].
	row addChild: setBtn; addChild: cmpBtn.
	box addChild: row.
	^ box
]

{ #category : 'accessing' }
ImageMapOverview >> classStats [
	"IdentityDictionary: class -> Array(kind index, bytes, object count), as of the scan."
	^ classStats
]

{ #category : 'ui' }
ImageMapOverview >> element [
	| root body mapHolder scroll selection |
	selection := ImageMapSelection new.
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
	scroll := (self mapElementOnSelect: [:aPage :el | self select: aPage element: el in: selection]) asScrollableElement.
	scroll constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	mapHolder addChild: scroll.
	body addChild: mapHolder; addChild: (self sideElementFor: selection).
	root addChild: body.
	^ root
]

{ #category : 'views' }
ImageMapOverview >> gtClassesFor: aView [
	<gtView>
	^ aView explicit
		title: 'Classes';
		priority: 2;
		stencil: [ImageMapMermaid classesElementFor: self]
]

{ #category : 'views' }
ImageMapOverview >> gtClassesSourceFor: aView [
	<gtView>
	^ aView textEditor
		title: 'Classes (Mermaid)';
		priority: 3;
		text: [ImageMapMermaid classesSourceFor: self]
]

{ #category : 'views' }
ImageMapOverview >> gtMapFor: aView [
	<gtView>
	^ aView explicit
		title: 'Map';
		priority: 1;
		stencil: [self element]
]

{ #category : 'views' }
ImageMapOverview >> gtNeighboursFor: aView [
	<gtView>
	^ aView explicit
		title: 'Neighbours';
		priority: 4;
		stencil: [ImageMapMermaid neighboursElementFor: self]
]

{ #category : 'views' }
ImageMapOverview >> gtNeighboursTableFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Neighbours (table)';
		priority: 5;
		items: [self kindTransitionRows sorted: [:a :b | a objects >= b objects]];
		column: 'Kind' text: [:r | r kind];
		column: 'Objects' text: [:r | r objects asStringWithCommas] width: 110;
		column: 'Same kind next' text: [:r | (r sameShare * 100) rounded printString, '%'] width: 120;
		column: 'Most often next' text: [:r | r nextShares ifEmpty: [''] ifNotEmpty: [:s | | a | a := s first. a key, ' ', (a value * 100) rounded printString, '%']]
]

{ #category : 'views' }
ImageMapOverview >> gtSizesFor: aView [
	<gtView>
	^ aView explicit
		title: 'Sizes';
		priority: 6;
		stencil: [ImageMapMermaid sizesElementFor: self]
]

{ #category : 'views' }
ImageMapOverview >> gtSizesTableFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Sizes (table)';
		priority: 7;
		items: [self sizeClassRows];
		column: 'Size' text: [:r | r label] width: 90;
		column: 'Objects' text: [:r | r objects asStringWithCommas] width: 110;
		column: 'MiB' text: [:r | ((r bytes / 1048576.0) printShowingDecimalPlaces: 2)] width: 80;
		column: 'Most bytes' text: [:r | r objects > 0 ifTrue: [r dominantKind] ifFalse: ['']]
]

{ #category : 'ui' }
ImageMapOverview >> heading: aString [
	^ ImageMapViewer new heading: aString
]

{ #category : 'ui' }
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
	row addChild: (self line: aKind asString, '  ', (self mebibytes: b), '  (', (b * 100 / (totalBytes max: 1)) rounded printString, '%)').
	^ row
]

{ #category : 'analysis' }
ImageMapOverview >> kindTotals [
	"Answer kind -> total bytes over all pages, biggest first."
	| sums |
	sums := Array new: ImageMapCell kinds size withAll: 0.
	pages do: [:p | 1 to: sums size do: [:i | sums at: i put: (sums at: i) + (p byKind at: i)]].
	^ ((1 to: sums size) collect: [:i | (ImageMapCell kinds at: i) -> (sums at: i)])
		asSortedCollection: [:a :b | a value >= b value]
]

{ #category : 'analysis' }
ImageMapOverview >> kindTransitionRows [
	"One ImageMapRow per kind that has objects: which kinds follow it in heap order. Answers an empty Array for an overview scanned before the transitions were counted."
	| kinds nk |
	transitions ifNil: [^ #()].
	kinds := ImageMapCell kinds.
	nk := kinds size.
	^ ((1 to: nk) collect: [:i | | counts sum |
		counts := (1 to: nk) collect: [:j | transitions at: (i - 1) * nk + j].
		sum := counts inject: 0 into: [:a :b | a + b].
		sum > 0
			ifTrue: [ImageMapRow new
				kind: (kinds at: i);
				objects: sum;
				sameShare: (counts at: i) / sum asFloat;
				nextShares: (((1 to: nk) select: [:j | (counts at: j) > 0]
					thenCollect: [:j | (kinds at: j) -> ((counts at: j) / sum asFloat)])
					asSortedCollection: [:a :b | a value >= b value]) asArray;
				yourself]
			ifFalse: [nil]]) select: [:r | r notNil]
]

{ #category : 'ui' }
ImageMapOverview >> line: aString [
	^ ImageMapViewer new line: aString
]

{ #category : 'ui' }
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

{ #category : 'formatting' }
ImageMapOverview >> mebibytes: bytes [
	^ (ImageMapCell roundedText: bytes / 1048576.0), ' MiB'
]

{ #category : 'accessing' }
ImageMapOverview >> pageBytes [
	^ pageBytes
]

{ #category : 'accessing' }
ImageMapOverview >> pages [
	^ pages
]

{ #category : 'printing' }
ImageMapOverview >> printOn: aStream [
	aStream nextPutAll: 'ImageMapOverview '; print: total; nextPutAll: ' objects, '; print: totalBytes // 1048576; nextPutAll: ' MiB, '; print: pages size; nextPutAll: ' pages'
]

{ #category : 'ui' }
ImageMapOverview >> refreshDetailIn: aSelection [
	| btn pg |
	aSelection detailBox removeChildren.
	aSelection item ifNil: [aSelection detailBox addChild: (self line: 'Click a block.'). ^ self].
	pg := aSelection item.
	{ 'offset: +', (pg offset printStringBase: 16).
	  'objects: ', pg objectCount printString.
	  'size: ', (pg bytes // 1024) printString, ' KiB'.
	  'first object: #', pg firstIndex printString, ' (at scan time)' }
		do: [:s | aSelection detailBox addChild: (self line: s)].
	(pg topKinds: 4) do: [:a |
		aSelection detailBox addChild: (self line: '  ', a key asString, '  ', (a value // 1024) printString, ' KiB  (', (a value * 100 // (pg bytes max: 1)) printString, '%)')].
	btn := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Open window here';
		margin: (BlInsets top: 8 left: 0 bottom: 0 right: 0).
	btn action: [ | w |
		w := pg isAnchorAlive
			ifTrue: [ImageMapSnapshot startingAt: pg firstObject count: 1024]
			ifFalse: [nil].
		w ifNil: [aSelection detailBox addChild: (self line: 'That object no longer exists (GC). Rescan the overview.')]
			ifNotNil: [btn phlow spawnObject: (ImageMapViewer on: w) viewName: 'Map']].
	aSelection detailBox addChild: btn
]

{ #category : 'private' }
ImageMapOverview >> scanPageBytes: aSize slow: aBoolean [
	"One pass over the heap. Besides the pages and the class statistics it counts which kind follows which kind (transitions) and how many objects and bytes each kind has in each size class (sizeCounts, sizeBytes)."
	| kinds nk cache i off nextBoundary cur tr sc sb pk |
	kinds := ImageMapCell kinds.
	nk := kinds size.
	cache := IdentityDictionary new.
	pageBytes := aSize.
	pages := OrderedCollection new.
	scannedAt := DateAndTime now.
	tr := Array new: nk * nk withAll: 0.
	sc := Array new: self class sizeClassCount * nk withAll: 0.
	sb := Array new: self class sizeClassCount * nk withAll: 0.
	pk := 0.
	i := 0. off := 0. nextBoundary := 0.
	SystemNavigation default allObjectsDo: [:o | | c e k sz b ix |
		c := aBoolean ifTrue: [[o class] on: Error do: [Object]] ifFalse: [o class].
		e := cache at: c ifAbsent: [nil].
		e ifNil: [e := cache at: c put: (Array with: (kinds indexOf: (ImageMapCell kindOfClass: c)) with: 0 with: 0)].
		k := e first.
		sz := aBoolean ifTrue: [[o sizeInMemory] on: Error do: [16]] ifFalse: [o sizeInMemory].
		sz isInteger ifFalse: [sz := c isVariable ifTrue: [16] ifFalse: [c byteSizeOfInstance]].
		off >= nextBoundary ifTrue: [
			cur := ImageMapPage new setFirstObject: o index: i offset: off kinds: nk.
			pages add: cur.
			nextBoundary := (off // aSize + 1) * aSize].
		cur addObject: sz kind: k.
		pk > 0 ifTrue: [ix := (pk - 1) * nk + k. tr at: ix put: (tr at: ix) + 1].
		pk := k.
		b := self class sizeClassOf: sz.
		ix := (b - 1) * nk + k.
		sc at: ix put: (sc at: ix) + 1.
		sb at: ix put: (sb at: ix) + sz.
		e at: 2 put: (e at: 2) + sz.
		e at: 3 put: (e at: 3) + 1.
		off := off + sz.
		i := i + 1].
	total := i.
	totalBytes := off.
	pages := pages asArray.
	classStats := cache.
	transitions := tr.
	sizeCounts := sc.
	sizeBytes := sb
]

{ #category : 'accessing' }
ImageMapOverview >> scannedAt [
	^ scannedAt
]

{ #category : 'ui' }
ImageMapOverview >> select: aPage element: anElement in: aSelection [
	aSelection element ifNotNil: [:prev | prev border: BlBorder empty].
	aSelection element: anElement; item: aPage.
	anElement border: (BlBorder paint: Color white width: 2).
	self refreshDetailIn: aSelection
]

{ #category : 'ui' }
ImageMapOverview >> sideElementFor: aSelection [
	| side classesBtn |
	side := BlElement new
		layout: BlLinearLayout vertical;
		padding: (BlInsets all: 8);
		constraintsDo: [:c | c horizontal exact: 300. c vertical fitContent].
	side addChild: (self heading: 'Heap').
	side addChild: (self line: total printString, ' objects').
	side addChild: (self line: (self mebibytes: totalBytes), ' of live objects').
	side addChild: (self line: pages size printString, ' blocks x ', (self mebibytes: pageBytes)).
	(ImageMapFormula elementForTex: '\text{start}_k=\min\{\,i:\ \text{offset}_i\ge k\cdot 2^{20}\,\}') ifNotNil: [:formula |
		side addChild: (formula margin: (BlInsets top: 4 left: 0 bottom: 0 right: 0)).
		side addChild: (self line: 'a block starts at the first object').
		side addChild: (self line: 'whose offset reaches k MiB')].
	side addChild: self baselineSection.
	side addChild: (self heading: 'Bytes by kind').
	self kindTotals do: [:a | a value > 0 ifTrue: [side addChild: (self kindBytesRow: a key bytes: a value)]].
	classesBtn := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Classes';
		margin: (BlInsets top: 8 left: 0 bottom: 0 right: 0).
	classesBtn action: [classesBtn phlow spawnObject: self viewName: 'Classes'].
	side addChild: classesBtn.
	side addChild: (self heading: 'Selected block').
	aSelection detailBox: (BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent];
		yourself).
	side addChild: aSelection detailBox.
	self refreshDetailIn: aSelection.
	^ side asScrollableElement
		constraintsDo: [:c | c horizontal exact: 300. c vertical matchParent];
		yourself
]

{ #category : 'accessing' }
ImageMapOverview >> sizeBytes [
	"The same as sizeCounts, in bytes."
	^ sizeBytes
]

{ #category : 'analysis' }
ImageMapOverview >> sizeClassRows [
	"One ImageMapRow per size class from the smallest to the biggest that has objects (classes in between may be empty): label, objects, bytes and the kind with most bytes. Answers an empty Array for an overview scanned before sizes were counted."
	| kinds nk rows first last |
	sizeCounts ifNil: [^ #()].
	kinds := ImageMapCell kinds.
	nk := kinds size.
	rows := (1 to: self class sizeClassCount) collect: [:b | | objs bytes best |
		objs := 0. bytes := 0. best := 1.
		1 to: nk do: [:k | | ix |
			ix := (b - 1) * nk + k.
			objs := objs + (sizeCounts at: ix).
			bytes := bytes + (sizeBytes at: ix).
			(sizeBytes at: ix) > (sizeBytes at: (b - 1) * nk + best) ifTrue: [best := k]].
		ImageMapRow new
			label: (self class sizeClassLabel: b);
			shortLabel: (self class sizeClassShortLabel: b);
			objects: objs;
			bytes: bytes;
			dominantKind: (kinds at: best);
			yourself].
	first := rows detect: [:r | r objects > 0] ifNone: [^ #()].
	last := rows reverse detect: [:r | r objects > 0].
	^ rows copyFrom: (rows indexOf: first) to: (rows indexOf: last)
]

{ #category : 'accessing' }
ImageMapOverview >> sizeCounts [
	"Flat Array, size classes x kinds: objects per size class and kind, at (class - 1) * kinds size + kind. Nil in an older overview."
	^ sizeCounts
]

{ #category : 'accessing' }
ImageMapOverview >> total [
	^ total
]

{ #category : 'accessing' }
ImageMapOverview >> totalBytes [
	^ totalBytes
]

{ #category : 'accessing' }
ImageMapOverview >> transitions [
	"Flat Array, kinds x kinds: the number of times an object of kind i is directly followed by an object of kind j, at (i - 1) * kinds size + j. Nil in an overview scanned before this was counted."
	^ transitions
]
