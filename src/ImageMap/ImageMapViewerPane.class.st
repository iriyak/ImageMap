"
I am one open picture of an ImageMapViewer: the toolbar, the block map, the side panel and what has been clicked in them. A viewer can be open more than once (ImageMapViewer openAt: answers the viewer and opens it, and inspecting that answer opens it a second time), so the parts and the selection are mine and not the viewer's: a click in one picture does not write into the side panel of another. The viewer keeps only where the window is. When the window moves (ImageMapViewer>>goto:), the viewer asks every pane that is still alive to refresh. I take the viewer's snapshot each time I need it, so I never show an old window.
"
Class {
	#name : 'ImageMapViewerPane',
	#superclass : 'Object',
	#instVars : [
		'viewer',
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
	#category : 'ImageMap-Window',
	#package : 'ImageMap',
	#tag : 'Window'
}

{ #category : 'instance creation' }
ImageMapViewerPane class >> on: aViewer [
	^ self new setViewer: aViewer
]

{ #category : 'ui' }
ImageMapViewerPane >> build [
	"The root element of this picture."
	| body |
	root := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	root addChild: self toolbar.
	root addChild: self snapshot legendElement.
	body := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	mapHolder := BlElement new
		constraintsDo: [:c | c horizontal exact: 332. c vertical matchParent].
	sidePanel := BlElement new
		layout: BlLinearLayout vertical;
		padding: (BlInsets all: 8);
		constraintsDo: [:c | c horizontal exact: 280. c vertical fitContent].
	body addChild: mapHolder; addChild: (sidePanel asScrollableElement
		constraintsDo: [:c | c horizontal exact: 280. c vertical matchParent];
		yourself).
	root addChild: body.
	self refresh.
	^ root
]

{ #category : 'navigation' }
ImageMapViewerPane >> gotoFromEditor [
	| n |
	n := (editor text asString reject: [:ch | ch = $, or: [ch isSeparator]]) asInteger.
	n ifNil: [^ self refreshControls].
	viewer goto: n
]

{ #category : 'ui' }
ImageMapViewerPane >> heading: aString [
	^ viewer heading: aString
]

{ #category : 'ui' }
ImageMapViewerPane >> kibibytes: bytes [
	^ (ImageMapCell roundedText: bytes / 1024.0), ' KiB'
]

{ #category : 'ui' }
ImageMapViewerPane >> kindRow: aKind stat: aPair [
	"aPair is (Array bytes objects), as ImageMapSnapshot>>kindStats answers."
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
	row addChild: (self line: aKind asString, '  ', (self kibibytes: aPair first), '  (', (aPair first * 100 / (self snapshot totalBytes max: 1)) rounded printString, '%)  ', aPair last asStringWithCommas, (aPair last = 1 ifTrue: [' object'] ifFalse: [' objects'])).
	^ row
]

{ #category : 'ui' }
ImageMapViewerPane >> line: aString [
	^ viewer line: aString
]

{ #category : 'ui' }
ImageMapViewerPane >> refresh [
	"The window has moved, or this is the first time: draw the map, the side panel and the controls again."
	| scroll |
	mapHolder removeChildren.
	selectedElement := nil.
	selectedCell := nil.
	scroll := (self snapshot mapElementOnSelect: [:cell :el | self select: cell element: el]) asScrollableElement.
	scroll constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	mapHolder addChild: scroll.
	self refreshSide.
	self refreshControls
]

{ #category : 'ui' }
ImageMapViewerPane >> refreshControls [
	| total |
	total := viewer total.
	editor text: self snapshot start printString.
	infoLabel text: self snapshot printString.
	thumb relocate: ((self snapshot start / total * 360) rounded min: 356) @ 0.
	thumb size: ((viewer count / total * 360) rounded max: 4) @ 16
]

{ #category : 'ui' }
ImageMapViewerPane >> refreshDetail [
	| btn refs row obj cell |
	detailBox removeChildren.
	selectedCell ifNil: [detailBox addChild: (self line: 'Click a block.'). ^ self].
	cell := selectedCell.
	obj := cell object.
	{ 'class: ', cell className.
	  'kind: ', cell kind asString.
	  'index: #', cell index printString.
	  'offset: +', (cell offset printStringBase: 16).
	  'size: ', cell bytes printString, ' B' }
		do: [:s | detailBox addChild: (self line: s)].
	row := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent];
		margin: (BlInsets top: 8 left: 0 bottom: 0 right: 0).
	btn := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Inspect';
		margin: (BlInsets right: 8).
	btn action: [btn phlow spawnObject: obj].
	refs := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'References'.
	refs action: [refs phlow spawnObject: (ImageMapReferences on: obj) viewName: 'Diagram'].
	row addChild: btn; addChild: refs.
	detailBox addChild: row
]

{ #category : 'ui' }
ImageMapViewerPane >> refreshSide [
	| classesBtn |
	sidePanel removeChildren.
	sidePanel addChild: (self heading: 'Bytes by kind').
	self snapshot kindStats do: [:a | sidePanel addChild: (self kindRow: a key stat: a value)].
	classesBtn := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Classes';
		margin: (BlInsets top: 8 left: 0 bottom: 0 right: 0).
	classesBtn action: [classesBtn phlow spawnObject: self snapshot viewName: 'Classes'].
	sidePanel addChild: classesBtn.
	sidePanel addChild: (self heading: 'Selected').
	detailBox := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent].
	sidePanel addChild: detailBox.
	self refreshDetail
]

{ #category : 'ui' }
ImageMapViewerPane >> select: aCell element: anElement [
	selectedElement ifNotNil: [:prev | prev border: BlBorder empty].
	selectedElement := anElement.
	selectedCell := aCell.
	anElement border: (BlBorder paint: Color white width: 2).
	self refreshDetail
]

{ #category : 'initialization' }
ImageMapViewerPane >> setViewer: aViewer [
	viewer := aViewer
]

{ #category : 'accessing' }
ImageMapViewerPane >> snapshot [
	^ viewer snapshot
]

{ #category : 'ui' }
ImageMapViewerPane >> toolbar [
	| bar prev next go |
	bar := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [:c | c horizontal matchParent. c vertical fitContent];
		padding: (BlInsets all: 6).
	prev := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Prev';
		margin: (BlInsets right: 6).
	prev action: [viewer goto: self snapshot start - viewer count].
	next := BrButton new
		aptitude: BrGlamorousButtonWithLabelAptitude new;
		label: 'Next';
		margin: (BlInsets right: 12).
	next action: [viewer goto: self snapshot start + viewer count].
	editor := BrEditor new
		aptitude: BrGlamorousEditorAptitude new;
		beMode: BrTextEditorEditableSingleLineMode new;
		text: self snapshot start printString;
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
ImageMapViewerPane >> trackElement [
	thumb := BlElement new size: 4 @ 16; background: (Color fromHexString: 'FFB52E').
	track := BlElement new
		size: 360 @ 16;
		background: (Color fromHexString: '3A4458');
		geometry: (BlRoundedRectangleGeometry cornerRadius: 3);
		margin: (BlInsets top: 4 left: 0 bottom: 0 right: 0);
		yourself.
	track addChild: thumb.
	track when: BlClickEvent do: [:evt | viewer goto: (evt localPosition x / 360 * viewer total) rounded].
	^ track
]

{ #category : 'accessing' }
ImageMapViewerPane >> viewer [
	^ viewer
]
