"
I compare the heap now with a baseline, an ImageMapOverview taken earlier, page by page. Create me with `ImageMapDiff against: anOverview`, or use the baseline kept on the class side: `ImageMapDiff takeBaseline`, do something to the image, then `ImageMapDiff open`. `ImageMapDiff clearBaseline` drops the baseline.

The first object of each baseline page is an anchor. I collect garbage, walk the heap in order and recognise the anchors one after another. The bytes of each kind between two anchors are compared with what the page held in the baseline. A page whose anchor has been collected is merged into the page before it, and bytes added after the last page show up as tail blocks (see ImageMapDiffCell). If the surviving anchors no longer appear in their old order, `isFullyAligned` is false and the views say so.

I draw the pages as blocks: filled for growth, outlined for shrinkage, coloured by the kind that changed most. My side panel lists the change by kind and the biggest class changes (`classChanges` has the change in bytes and objects for every class).

My Class changes view draws the classes whose bytes changed most as a bar chart (ImageMapMermaid, needs Pele2svg), and Class changes (table) lists them all.

I am experimental.
"
Class {
	#name : 'ImageMapDiff',
	#superclass : 'Object',
	#instVars : [
		'before',
		'afterTotal',
		'afterBytes',
		'afterClassStats',
		'spanKindBytes',
		'spanObjects',
		'matched',
		'matchedCount',
		'cells',
		'classChanges',
		'beforeKindBytes',
		'afterKindBytes',
		'detailBox',
		'selectedElement',
		'selectedCell',
		'selectedBorder'
	],
	#classVars : [
		'Baseline'
	],
	#category : 'ImageMap-Diff',
	#package : 'ImageMap',
	#tag : 'Diff'
}

{ #category : 'instance creation' }
ImageMapDiff class >> against: aBaseline [
	^ self new setBaseline: aBaseline
]

{ #category : 'baseline' }
ImageMapDiff class >> baseline [
	^ Baseline
]

{ #category : 'baseline' }
ImageMapDiff class >> baseline: anOverview [
	Baseline := anOverview
]

{ #category : 'baseline' }
ImageMapDiff class >> baselineDescription [
	^ Baseline
		ifNil: ['none yet']
		ifNotNil: [:b | 'taken at ', b scannedAt asTime printString, ' (', b total printString, ' objects)']
]

{ #category : 'baseline' }
ImageMapDiff class >> clearBaseline [
	Baseline := nil
]

{ #category : 'baseline' }
ImageMapDiff class >> compareToBaseline [
	Baseline ifNil: [^ self error: 'No baseline yet: run ImageMapDiff takeBaseline first'].
	^ self against: Baseline
]

{ #category : 'opening' }
ImageMapDiff class >> open [
	"Compare the heap now with the baseline and open the result (in the UI process)."
	| aDiff |
	aDiff := self compareToBaseline.
	UIManager default defer: [aDiff inspect].
	^ aDiff
]

{ #category : 'baseline' }
ImageMapDiff class >> takeBaseline [
	"Scan the heap now and keep the result as the baseline for later comparisons."
	^ Baseline := ImageMapOverview scan
]

{ #category : 'accessing' }
ImageMapDiff >> afterBytes [
	^ afterBytes
]

{ #category : 'accessing' }
ImageMapDiff >> afterKindBytes [
	^ afterKindBytes
]

{ #category : 'accessing' }
ImageMapDiff >> afterTotal [
	^ afterTotal
]

{ #category : 'accessing' }
ImageMapDiff >> before [
	^ before
]

{ #category : 'accessing' }
ImageMapDiff >> beforeKindBytes [
	^ beforeKindBytes
]

{ #category : 'ui' }
ImageMapDiff >> cellLabel: aCell [
	| s |
	aCell isMerged ifTrue: [^ 'baseline page ', aCell pageNumber printString, ': anchor gone, counted in page ', aCell mergedInto printString].
	s := WriteStream on: String new.
	aCell isTail
		ifTrue: [s nextPutAll: 'new since baseline (after the last baseline page)']
		ifFalse: [s nextPutAll: 'baseline page '; print: aCell pageNumber; nextPutAll: ' +'; nextPutAll: ((before pages at: aCell pageNumber) offset printStringBase: 16)].
	(aCell topChanges: 3) do: [:a | s nextPutAll: '  '; nextPutAll: a key asString; nextPutAll: ' '; nextPutAll: (self signedBytes: a value)].
	^ s contents
]

{ #category : 'accessing' }
ImageMapDiff >> cells [
	^ cells
]

{ #category : 'accessing' }
ImageMapDiff >> classChanges [
	"Array of Array(class, byte change, object count change, bytes before, bytes after), biggest increase first."
	^ classChanges
]

{ #category : 'ui' }
ImageMapDiff >> classRow: anEntry [
	^ self line: ((anEntry at: 1) name), '  ', (self signedBytes: (anEntry at: 2)), '  (', ((anEntry at: 3) >= 0 ifTrue: ['+'] ifFalse: ['']), (anEntry at: 3) printString, ' objects)'
]

{ #category : 'private' }
ImageMapDiff >> computeCells [
	| nk pagesA p pb leaders leaderOf cur groupBytes groupSizes last tailKinds tailTotal keys |
	nk := ImageMapCell kinds size.
	pagesA := before pages.
	p := pagesA size.
	pb := before pageBytes.
	beforeKindBytes := Array new: nk withAll: 0.
	afterKindBytes := Array new: nk withAll: 0.
	pagesA do: [:pg | 1 to: nk do: [:k | beforeKindBytes at: k put: (beforeKindBytes at: k) + (pg byKind at: k)]].
	spanKindBytes do: [:row | 1 to: nk do: [:k | afterKindBytes at: k put: (afterKindBytes at: k) + (row at: k)]].
	"Pages whose anchor is gone, or was not met, are folded into the nearest earlier page whose anchor was met."
	leaders := (1 to: p) select: [:j | matched at: j].
	leaders isEmpty ifTrue: [leaders := Array with: 1].
	leaderOf := Array new: p.
	cur := leaders first.
	1 to: p do: [:j | (matched at: j) ifTrue: [cur := j]. leaderOf at: j put: cur].
	groupBytes := Array new: p.
	groupSizes := Array new: p withAll: 0.
	leaders do: [:j | groupBytes at: j put: (Array new: nk withAll: 0)].
	1 to: p do: [:j | | ld g |
		ld := leaderOf at: j.
		g := groupBytes at: ld.
		1 to: nk do: [:k | g at: k put: (g at: k) + ((pagesA at: j) byKind at: k)].
		groupSizes at: ld put: (groupSizes at: ld) + 1].
	cells := OrderedCollection new.
	1 to: p do: [:j | | ld |
		ld := leaderOf at: j.
		j = ld
			ifTrue: [cells add: (ImageMapDiffCell new
				pageNumber: j; isTail: false; aligned: true; groupSize: (groupSizes at: j);
				deltas: ((1 to: nk) collect: [:k | ((spanKindBytes at: j) at: k) - ((groupBytes at: j) at: k)]);
				afterObjects: (spanObjects at: j); yourself)]
			ifFalse: [cells add: (ImageMapDiffCell new
				pageNumber: j; isTail: false; aligned: true; mergedInto: ld; groupSize: 1;
				deltas: (Array new: nk withAll: 0); afterObjects: 0; yourself)]].
	"Bytes added after the last baseline page: move the positive part of the last leader into tail blocks."
	true ifTrue: [
		last := cells detect: [:c | c pageNumber = leaders last].
		tailKinds := last deltas collect: [:x | x max: 0].
		last deltas: (last deltas collect: [:x | x min: 0]).
		tailTotal := tailKinds inject: 0 into: [:s :x | s + x].
		tailTotal > 0 ifTrue: [
			1 to: (tailTotal / pb) ceiling do: [:t | | share |
				share := (tailTotal - ((t - 1) * pb)) min: pb.
				cells add: (ImageMapDiffCell new
					pageNumber: nil; isTail: true; aligned: true; groupSize: 0;
					deltas: (tailKinds collect: [:x | x * share // tailTotal]);
					afterObjects: 0; yourself)]]].
	keys := IdentitySet new.
	before classStats keysDo: [:c | keys add: c].
	afterClassStats keysDo: [:c | keys add: c].
	classChanges := (keys asArray collect: [:c | | a b |
		a := before classStats at: c ifAbsent: [#(0 0 0)].
		b := afterClassStats at: c ifAbsent: [#(0 0 0)].
		Array with: c with: (b at: 2) - (a at: 2) with: (b at: 3) - (a at: 3) with: (a at: 2) with: (b at: 2)])
			asSortedCollection: [:x :y | (x at: 2) >= (y at: 2)].
	classChanges := classChanges asArray
]

{ #category : 'ui' }
ImageMapDiff >> element [
	| root body mapHolder scroll |
	selectedElement := nil.
	selectedCell := nil.
	selectedBorder := nil.
	root := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	root addChild: ImageMapSnapshot new legendElement.
	root addChild: ((self line: 'One block = one baseline page. Filled = grew, outline = shrank; colour = the kind that changed most; stronger = bigger change (full at 256 KiB).')
		margin: (BlInsets left: 6); yourself).
	root addChild: ((self line: 'Dark = unchanged (under 4 KiB), darker = folded into an earlier page, rows labelled new = bytes added after the last baseline page.')
		margin: (BlInsets left: 6); yourself).
	body := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	mapHolder := BlElement new
		constraintsDo: [:c | c horizontal exact: 470. c vertical matchParent].
	scroll := (self mapElementOnSelect: [:aCell :el | self select: aCell element: el]) asScrollableElement.
	scroll constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	mapHolder addChild: scroll.
	body addChild: mapHolder; addChild: self sideElement.
	root addChild: body.
	^ root
]

{ #category : 'views' }
ImageMapDiff >> gtClassChangesFor: aView [
	<gtView>
	^ aView explicit
		title: 'Class changes';
		priority: 2;
		stencil: [ImageMapMermaid classChangesElementFor: self]
]

{ #category : 'views' }
ImageMapDiff >> gtClassChangesTableFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Class changes (table)';
		priority: 3;
		items: [self classChanges select: [:r | (r at: 2) ~= 0 or: [(r at: 3) ~= 0]]];
		column: 'Class' text: [:r | (r at: 1) name];
		column: 'Change KiB' text: [:r | ((r at: 2) / 1024.0) printShowingDecimalPlaces: 1] width: 110;
		column: 'Change objects' text: [:r | (r at: 3) printString] width: 120;
		column: 'Before KiB' text: [:r | ((r at: 4) / 1024.0) printShowingDecimalPlaces: 1] width: 110;
		column: 'After KiB' text: [:r | ((r at: 5) / 1024.0) printShowingDecimalPlaces: 1] width: 110
]

{ #category : 'views' }
ImageMapDiff >> gtMapFor: aView [
	<gtView>
	^ aView explicit
		title: 'Map';
		priority: 1;
		stencil: [self element]
]

{ #category : 'ui' }
ImageMapDiff >> heading: aString [
	^ ImageMapViewer new heading: aString
]

{ #category : 'testing' }
ImageMapDiff >> isFullyAligned [
	"True when every anchor that is still alive was met in order (anchors that were collected are fine)."
	^ (before pages count: [:pg | pg isAnchorAlive]) = matchedCount
]

{ #category : 'ui' }
ImageMapDiff >> kindRow: aKind index: k [
	| row sq a b |
	a := beforeKindBytes at: k.
	b := afterKindBytes at: k.
	row := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent].
	sq := BlElement new
		size: 12 @ 12;
		background: (ImageMapCell colorFor: aKind);
		geometry: (BlRoundedRectangleGeometry cornerRadius: 2);
		margin: (BlInsets top: 4 left: 0 bottom: 0 right: 6).
	row addChild: sq.
	row addChild: (self line: aKind asString, '  ', (self signedBytes: b - a), '  (', (a // 1024) printString, ' -> ', (b // 1024) printString, ' KiB)').
	^ row
]

{ #category : 'ui' }
ImageMapDiff >> line: aString [
	^ ImageMapViewer new line: aString
]

{ #category : 'accessing' }
ImageMapDiff >> lostAnchors [
	^ before pages count: [:pg | pg isAnchorAlive not]
]

{ #category : 'ui' }
ImageMapDiff >> mapElementOnSelect: aBlock [
	| pitch cellSize labelWidth cols rows root |
	pitch := 22. cellSize := 20. labelWidth := 84. cols := 16.
	rows := (cells size / cols) ceiling.
	root := BlElement new
		size: (labelWidth + (cols * pitch) + 8) @ (rows * pitch + 8);
		background: (Color fromHexString: '1B2230').
	cells doWithIndex: [:cell :n | | col row el d mag kindColor |
		col := (n - 1) \\ cols.
		row := (n - 1) // cols.
		el := BlElement new
			size: cellSize @ cellSize;
			relocate: (labelWidth + (col * pitch)) @ (row * pitch + 4);
			geometry: (BlRoundedRectangleGeometry cornerRadius: 3).
		cell isMerged
			ifTrue: [el background: (Color fromHexString: '171D29')]
			ifFalse: [
				d := cell dominantDelta.
				mag := d abs.
				mag < 4096
					ifTrue: [el background: (Color fromHexString: '2F394D')]
					ifFalse: [
						kindColor := ImageMapCell colorFor: cell dominantKind.
						el opacity: (((mag / 262144.0) max: 0.35) min: 1.0).
						d > 0
							ifTrue: [el background: kindColor]
							ifFalse: [el background: (Color fromHexString: '1B2230'); border: (BlBorder paint: kindColor width: 2)]]].
		el addAptitude: (BrGlamorousWithTooltipAptitude content: [
			BrLabel new aptitude: BrGlamorousLabelAptitude; text: (self cellLabel: cell)]).
		el when: BlClickEvent do: [:evt | aBlock value: cell value: evt currentTarget].
		root addChild: el].
	0 to: rows - 1 do: [:r | | first t txt |
		first := cells at: r * cols + 1.
		txt := first isTail
			ifTrue: ['new']
			ifFalse: [((before pages at: first pageNumber) offset printStringBase: 16) asUppercase].
		t := txt asRopedText.
		t foreground: (Color fromHexString: '8A94A6'); fontSize: 10.
		root addChild: (BlTextElement new text: t; relocate: 4 @ (r * pitch + 6))].
	^ root
]

{ #category : 'accessing' }
ImageMapDiff >> matchedCount [
	^ matchedCount
]

{ #category : 'formatting' }
ImageMapDiff >> plainBytes: n [
	| a |
	a := n abs.
	^ a >= 1048576
		ifTrue: [((a * 10 // 1048576) / 10.0) printString, ' MiB']
		ifFalse: [a >= 1024
			ifTrue: [(a // 1024) printString, ' KiB']
			ifFalse: [a printString, ' B']]
]

{ #category : 'printing' }
ImageMapDiff >> printOn: aStream [
	aStream
		nextPutAll: 'ImageMapDiff '; print: before total; nextPutAll: ' -> '; print: afterTotal; nextPutAll: ' objects, ';
		print: before totalBytes // 1048576; nextPutAll: ' -> '; print: afterBytes // 1048576; nextPutAll: ' MiB';
		nextPutAll: ', anchors '; print: matchedCount; nextPut: $/; print: before pages size.
	self isFullyAligned ifFalse: [aStream nextPutAll: ' (ORDER CHANGED)']
]

{ #category : 'ui' }
ImageMapDiff >> refreshDetail [
	| btn c pg |
	detailBox removeChildren.
	selectedCell ifNil: [detailBox addChild: (self line: 'Click a block.'). ^ self].
	c := selectedCell.
	c isMerged ifTrue: [
		detailBox addChild: (self line: 'baseline page ', c pageNumber printString).
		detailBox addChild: (self line: 'its first object is gone;').
		detailBox addChild: (self line: 'counted in page ', c mergedInto printString, '.').
		^ self].
	c isTail
		ifTrue: [detailBox addChild: (self line: 'added after the last baseline page')]
		ifFalse: [
			pg := before pages at: c pageNumber.
			detailBox addChild: (self line: 'baseline page ', c pageNumber printString, '  +', (pg offset printStringBase: 16)).
			c groupSize > 1 ifTrue: [detailBox addChild: (self line: '(includes ', (c groupSize - 1) printString, ' following page(s) whose first object is gone)')].
			detailBox addChild: (self line: 'objects in range now: ', c afterObjects printString)].
	(c topChanges: 6) isEmpty ifTrue: [detailBox addChild: (self line: 'no change')].
	(c topChanges: 6) do: [:a | detailBox addChild: (self line: '  ', a key asString, '  ', (self signedBytes: a value))].
	(c isTail not and: [pg isAnchorAlive]) ifTrue: [
		btn := BrButton new
			aptitude: BrGlamorousButtonWithLabelAptitude new;
			label: 'Open window here (now)';
			margin: (BlInsets top: 8 left: 0 bottom: 0 right: 0).
		btn action: [ | w |
			w := ImageMapSnapshot startingAt: pg firstObject count: 1024.
			w ifNil: [detailBox addChild: (self line: 'That object no longer exists (GC).')]
				ifNotNil: [btn phlow spawnObject: (ImageMapViewer on: w) viewName: 'Map']].
		detailBox addChild: btn]
]

{ #category : 'private' }
ImageMapDiff >> scanSlow: aBoolean [
	| kinds nk pagesA p spanKinds spanObjs cache nextJ haveNext nextAnchor cur i off isMatched |
	kinds := ImageMapCell kinds.
	nk := kinds size.
	pagesA := before pages.
	p := pagesA size.
	spanKinds := (1 to: p) collect: [:j | Array new: nk withAll: 0].
	spanObjs := Array new: p withAll: 0.
	isMatched := Array new: p withAll: false.
	cache := IdentityDictionary new.
	cur := 1. nextJ := 1.
	[nextJ <= p and: [(pagesA at: nextJ) isAnchorAlive not]] whileTrue: [nextJ := nextJ + 1].
	haveNext := nextJ <= p.
	nextAnchor := haveNext ifTrue: [(pagesA at: nextJ) firstObject] ifFalse: [nil].
	i := 0. off := 0.
	SystemNavigation default allObjectsDo: [:o | | c e k sz row |
		(haveNext and: [o == nextAnchor]) ifTrue: [
			cur := nextJ.
			isMatched at: cur put: true.
			nextJ := nextJ + 1.
			[nextJ <= p and: [(pagesA at: nextJ) isAnchorAlive not]] whileTrue: [nextJ := nextJ + 1].
			haveNext := nextJ <= p.
			nextAnchor := haveNext ifTrue: [(pagesA at: nextJ) firstObject] ifFalse: [nil]].
		c := aBoolean ifTrue: [[o class] on: Error do: [Object]] ifFalse: [o class].
		e := cache at: c ifAbsent: [nil].
		e ifNil: [e := cache at: c put: (Array with: (kinds indexOf: (ImageMapCell kindOfClass: c)) with: 0 with: 0)].
		k := e first.
		sz := aBoolean ifTrue: [[o sizeInMemory] on: Error do: [16]] ifFalse: [o sizeInMemory].
		sz isInteger ifFalse: [sz := c isVariable ifTrue: [16] ifFalse: [c byteSizeOfInstance]].
		row := spanKinds at: cur.
		row at: k put: (row at: k) + sz.
		spanObjs at: cur put: (spanObjs at: cur) + 1.
		e at: 2 put: (e at: 2) + sz.
		e at: 3 put: (e at: 3) + 1.
		off := off + sz.
		i := i + 1].
	matched := isMatched.
	matchedCount := isMatched count: [:b | b].
	afterTotal := i.
	afterBytes := off.
	afterClassStats := cache.
	spanKindBytes := spanKinds.
	spanObjects := spanObjs
]

{ #category : 'ui' }
ImageMapDiff >> select: aCell element: anElement [
	selectedElement ifNotNil: [:prev | prev border: selectedBorder].
	selectedElement := anElement.
	selectedBorder := anElement border.
	selectedCell := aCell.
	anElement border: (BlBorder paint: Color white width: 2).
	self refreshDetail
]

{ #category : 'initialization' }
ImageMapDiff >> setBaseline: aBaseline [
	before := aBaseline.
	Smalltalk garbageCollect.
	[self scanSlow: false] on: Error do: [:e | self scanSlow: true].
	self computeCells
]

{ #category : 'ui' }
ImageMapDiff >> sideElement [
	| side kindsSorted gainers losers |
	side := BlElement new
		layout: BlLinearLayout vertical;
		padding: (BlInsets all: 8);
		constraintsDo: [:c | c horizontal exact: 330. c vertical matchParent].
	side addChild: (self heading: 'Heap change').
	side addChild: (self line: 'objects: ', before total printString, ' -> ', afterTotal printString, '  (', ((afterTotal - before total) >= 0 ifTrue: ['+'] ifFalse: ['']), (afterTotal - before total) printString, ')').
	side addChild: (self line: 'live size: ', (self plainBytes: before totalBytes), ' -> ', (self plainBytes: afterBytes), '  (', (self signedBytes: afterBytes - before totalBytes), ')').
	side addChild: (self line: 'baseline taken at ', before scannedAt asTime printString).
	side addChild: (self line: 'anchors met: ', matchedCount printString, ' of ', before pages size printString, ' pages (gone: ', self lostAnchors printString, ')').
	self isFullyAligned ifFalse: [side addChild: (self line: '! heap order changed for some pages; they were folded into the page before.')].
	side addChild: (self heading: 'Change by kind').
	kindsSorted := (1 to: beforeKindBytes size) asSortedCollection: [:x :y | ((afterKindBytes at: x) - (beforeKindBytes at: x)) abs >= ((afterKindBytes at: y) - (beforeKindBytes at: y)) abs].
	kindsSorted do: [:k | ((afterKindBytes at: k) - (beforeKindBytes at: k)) abs >= 1024 ifTrue: [side addChild: (self kindRow: (ImageMapCell kinds at: k) index: k)]].
	side addChild: (self heading: 'Biggest class changes').
	gainers := classChanges first: (8 min: classChanges size).
	gainers do: [:e | (e at: 2) > 0 ifTrue: [side addChild: (self classRow: e)]].
	losers := (classChanges last: (5 min: classChanges size)) reverse.
	losers do: [:e | (e at: 2) < 0 ifTrue: [side addChild: (self classRow: e)]].
	side addChild: (self heading: 'Selected block').
	detailBox := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent].
	side addChild: detailBox.
	self refreshDetail.
	^ side
]

{ #category : 'formatting' }
ImageMapDiff >> signedBytes: n [
	| a |
	a := n abs.
	^ (n < 0 ifTrue: ['-'] ifFalse: ['+']), (a >= 1048576
		ifTrue: [((a * 10 // 1048576) / 10.0) printString, ' MiB']
		ifFalse: [a >= 1024
			ifTrue: [(a // 1024) printString, ' KiB']
			ifFalse: [a printString, ' B']])
]
