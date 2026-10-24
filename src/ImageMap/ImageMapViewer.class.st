"
Interactive view over ImageMapSnapshot windows: toolbar (prev/next, start index, position bar), the block map, and a side panel with per-kind counts and details of the selected block.
"
Class {
	#name : 'ImageMapViewer',
	#superclass : 'Object',
	#instVars : [
		'snapshot',
		'count',
		'total',
		'root',
		'mapHolder',
		'sidePanel',
		'detailBox',
		'editor',
		'track',
		'thumb',
		'infoLabel',
		'selectedElement',
		'selectedCell'
	],
	#category : 'ImageMap',
	#package : 'ImageMap'
}

{ #category : 'instance creation' }
ImageMapViewer class >> on: aSnapshot [
	^ self new setSnapshot: aSnapshot
]

{ #category : 'opening' }
ImageMapViewer class >> openAt: aStart [
	"Open an inspector on a viewer positioned at aStart. The inspector is opened in the UI process, so this is safe to call from any process (e.g. an MCP/REPL worker); GT text editors assert they run in the UI process."
	| aViewer |
	aViewer := self on: (ImageMapSnapshot start: aStart count: 1024).
	UIManager default defer: [aViewer inspect].
	^ aViewer
]

{ #category : 'accessing' }
ImageMapViewer class >> totalObjects [
	| n |
	n := 0.
	SystemNavigation default allObjectsDo: [:o | n := n + 1].
	^ n
]

{ #category : 'ui' }
ImageMapViewer >> buildRoot [
	| body |
	root := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	root addChild: self toolbar.
	root addChild: snapshot legendElement.
	body := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	mapHolder := BlElement new
		constraintsDo: [:c | c horizontal exact: 332. c vertical matchParent].
	sidePanel := BlElement new
		layout: BlLinearLayout vertical;
		padding: (BlInsets all: 8);
		constraintsDo: [:c | c horizontal exact: 280. c vertical matchParent].
	body addChild: mapHolder; addChild: sidePanel.
	root addChild: body.
	self refresh.
	^ root
]

{ #category : 'ui' }
ImageMapViewer >> element [
	^ self buildRoot
]

{ #category : 'navigation' }
ImageMapViewer >> goto: aStart [
	"Move the window. The total object count can shrink after a GC, so when the window comes back short, recount and clamp again."
	| s |
	s := (aStart max: 0) min: (total - count max: 0).
	snapshot := ImageMapSnapshot start: s count: count.
	(snapshot count < count and: [total > count]) ifTrue: [
		total := self class totalObjects.
		s := (aStart max: 0) min: (total - count max: 0).
		snapshot := ImageMapSnapshot start: s count: count].
	self refresh
]

{ #category : 'navigation' }
ImageMapViewer >> gotoFromEditor [
	| n |
	n := (editor text asString reject: [:ch | ch = $, or: [ch isSeparator]]) asInteger.
	n ifNil: [^ self refreshControls].
	self goto: n
]

{ #category : 'views' }
ImageMapViewer >> gtMapFor: aView [
	<gtView>
	^ aView explicit
		title: 'Map';
		priority: 1;
		stencil: [self element]
]

{ #category : 'ui' }
ImageMapViewer >> heading: aString [
	^ BrLabel new
		aptitude: BrGlamorousLabelAptitude new;
		text: aString asRopedText bold;
		margin: (BlInsets top: 12 left: 0 bottom: 4 right: 0);
		yourself
]

{ #category : 'ui' }
ImageMapViewer >> kindRow: aKind count: anInteger [
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
	row addChild: (self line: aKind asString, '  ', anInteger printString, '  (', (anInteger * 100 // (snapshot count max: 1)) printString, '%)').
	^ row
]

{ #category : 'ui' }
ImageMapViewer >> line: aString [
	^ BrLabel new aptitude: BrGlamorousLabelAptitude new; text: aString; yourself
]

{ #category : 'printing' }
ImageMapViewer >> printOn: aStream [
	aStream nextPutAll: 'ImageMapViewer on '; print: snapshot
]

{ #category : 'ui' }
ImageMapViewer >> refresh [
	| scroll |
	mapHolder removeChildren.
	selectedElement := nil.
	selectedCell := nil.
	scroll := (snapshot mapElementOnSelect: [:cell :el | self select: cell element: el]) asScrollableElement.
	scroll constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	mapHolder addChild: scroll.
	self refreshSide.
	self refreshControls
]

{ #category : 'ui' }
ImageMapViewer >> refreshControls [
	editor text: snapshot start printString.
	infoLabel text: snapshot printString.
	thumb relocate: ((snapshot start / total * 360) rounded min: 356) @ 0.
	thumb size: ((count / total * 360) rounded max: 4) @ 16
]

{ #category : 'ui' }
ImageMapViewer >> refreshDetail [
	| btn obj |
	detailBox removeChildren.
	selectedCell ifNil: [detailBox addChild: (self line: 'Click a block.'). ^ self].
	obj := selectedCell object.
	{ 'class: ', selectedCell className.
	  'kind: ', selectedCell kind asString.
	  'index: #', selectedCell index printString.
	  'offset: +', (selectedCell offset printStringBase: 16).
	  'size: ', selectedCell bytes printString, ' B' }
		do: [:s | detailBox addChild: (self line: s)].
	btn := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Inspect';
		margin: (BlInsets top: 8 left: 0 bottom: 0 right: 0).
	btn action: [btn phlow spawnObject: obj].
	detailBox addChild: btn
]

{ #category : 'ui' }
ImageMapViewer >> refreshSide [
	sidePanel removeChildren.
	sidePanel addChild: (self heading: 'Kinds in this window').
	snapshot kindCounts do: [:a | sidePanel addChild: (self kindRow: a key count: a value)].
	sidePanel addChild: (self heading: 'Selected').
	detailBox := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent].
	sidePanel addChild: detailBox.
	self refreshDetail
]

{ #category : 'ui' }
ImageMapViewer >> select: aCell element: anElement [
	selectedElement ifNotNil: [:prev | prev border: BlBorder empty].
	selectedElement := anElement.
	selectedCell := aCell.
	anElement border: (BlBorder paint: Color white width: 2).
	self refreshDetail
]

{ #category : 'initialization' }
ImageMapViewer >> setSnapshot: aSnapshot [
	snapshot := aSnapshot.
	count := 1024.
	total := self class totalObjects
]

{ #category : 'accessing' }
ImageMapViewer >> snapshot [
	^ snapshot
]

{ #category : 'ui' }
ImageMapViewer >> toolbar [
	| bar prev next go |
	bar := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent];
		padding: (BlInsets all: 6).
	prev := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Prev';
		margin: (BlInsets right: 6).
	prev action: [self goto: snapshot start - count].
	next := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Next';
		margin: (BlInsets right: 12).
	next action: [self goto: snapshot start + count].
	editor := BrEditor new
		aptitude: BrGlamorousEditorAptitude new;
		beMode: BrTextEditorEditableSingleLineMode new;
		text: snapshot start printString;
		constraintsDo: [:c | c horizontal exact: 110. c vertical fitContent];
		margin: (BlInsets right: 6);
		yourself.
	editor when: BlKeyDownEvent do: [:e | e key = BlKeyboardKey return ifTrue: [self gotoFromEditor. e consumed: true]].
	go := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Go';
		margin: (BlInsets right: 12).
	go action: [self gotoFromEditor].
	infoLabel := (self line: '') margin: (BlInsets left: 12); yourself.
	bar addChild: prev; addChild: next; addChild: editor; addChild: go; addChild: self trackElement; addChild: infoLabel.
	^ bar
]

{ #category : 'ui' }
ImageMapViewer >> trackElement [
	thumb := BlElement new size: 4 @ 16; background: (Color fromHexString: 'FFB52E').
	track := BlElement new
		size: 360 @ 16;
		background: (Color fromHexString: '3A4458');
		geometry: (BlRoundedRectangleGeometry cornerRadius: 3);
		margin: (BlInsets top: 4 left: 0 bottom: 0 right: 0);
		yourself.
	track addChild: thumb.
	track when: BlClickEvent do: [:evt | self goto: (evt localPosition x / 360 * total) rounded].
	^ track
]
