"
I am the interactive window shown in the Map tab of an ImageMapSnapshot. I have a toolbar (Prev, Next, a start-index field with Go, and a position bar that moves the window over the whole heap), a legend, the block map, and a side panel. The side panel shows the bytes per kind in the window (with the share and the number of objects), as ImageMapOverview does for the whole heap, a Classes button that opens the Classes view of the snapshot (bytes by kind and class as a diagram; I also have the same Classes and Classes (Mermaid) views myself, and they follow the window when it moves), and the details of the selected block (class, kind, index, offset, size) with Inspect and References buttons. Inspect opens the object in an inspector, and References opens an ImageMapReferences: the class chain and the slots of the object as a diagram.

Open me with `ImageMapViewer openAt: 5000000`. The window is opened in the UI process, so this can be called from any process. `ImageMapViewer on: aSnapshot` builds me for a snapshot you already have. `goto:` moves the window: it keeps the start inside the heap and counts the objects again if the heap has shrunk.

I keep only where the window is (the snapshot, and how many objects it has). What is on the screen, the toolbar, the block map, the side panel and what has been clicked, belongs to an ImageMapViewerPane, one for each picture I am shown in, so I can be open more than once at the same time (ImageMapViewer openAt: opens me, and inspecting its answer opens me a second time). `goto:` moves the window and redraws every picture that is still alive, and the Classes and Classes (Mermaid) tabs.
"
Class {
	#name : 'ImageMapViewer',
	#superclass : 'Object',
	#instVars : [
		'snapshot',
		'count',
		'total',
		'followers',
		'panes'
	],
	#category : 'ImageMap-Window',
	#package : 'ImageMap',
	#tag : 'Window'
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

{ #category : 'accessing' }
ImageMapViewer >> count [
	^ count
]

{ #category : 'ui' }
ImageMapViewer >> element [
	"A new picture of this viewer: its own toolbar, map, side panel and selection. The viewer keeps the pictures (weakly), and moves them all when the window moves."
	| pane |
	pane := ImageMapViewerPane on: self.
	panes ifNil: [panes := WeakSet new].
	panes add: pane.
	^ pane build
]

{ #category : 'private' }
ImageMapViewer >> fillFollower: aHolder [
	| content |
	content := (aHolder userData at: #build) value.
	content constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	aHolder removeChildren.
	aHolder addChild: content.
	aHolder userData at: #stale put: false
]

{ #category : 'private' }
ImageMapViewer >> followingElementFrom: aBlock [
	"An element for a tab of the inspector that shows the window of this viewer, and follows it. aBlock builds the content from the current snapshot. The content is built now, rebuilt when the window moves while the tab is on screen, and marked stale when the window moves while it is not: it is then rebuilt when the tab comes back. Drawing a diagram starts a process, so nothing is drawn for a tab that nobody looks at."
	| holder |
	holder := BlElement new
		layout: BlFrameLayout new;
		constraintsDo: [:c | c horizontal matchParent. c vertical matchParent].
	holder userData at: #build put: aBlock.
	self fillFollower: holder.
	holder when: BlElementAddedToSceneGraphEvent do: [:e |
		(holder userData at: #stale ifAbsent: [false]) ifTrue: [self fillFollower: holder]].
	followers ifNil: [followers := WeakSet new].
	followers add: holder.
	^ holder
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
	self refreshPanes.
	self refreshFollowers
]

{ #category : 'views' }
ImageMapViewer >> gtClassesFor: aView [
	<gtView>
	^ aView explicit
		title: 'Classes';
		priority: 2;
		stencil: [self followingElementFrom: [ImageMapMermaid classesElementForSnapshot: snapshot]]
]

{ #category : 'views' }
ImageMapViewer >> gtClassesSourceFor: aView [
	<gtView>
	^ aView explicit
		title: 'Classes (Mermaid)';
		priority: 3;
		stencil: [self followingElementFrom: [
			BrEditor new
				aptitude: BrGlamorousRegularEditorAptitude new;
				text: (ImageMapMermaid classesSourceForSnapshot: snapshot);
				beReadOnlyWithSelection;
				yourself]]
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
ImageMapViewer >> line: aString [
	^ BrLabel new aptitude: BrGlamorousLabelAptitude new; text: aString; yourself
]

{ #category : 'printing' }
ImageMapViewer >> printOn: aStream [
	aStream nextPutAll: 'ImageMapViewer on '; print: snapshot
]

{ #category : 'private' }
ImageMapViewer >> refreshFollowers [
	"The window has moved: update the tabs that follow it."
	followers ifNil: [^ self].
	followers copy do: [:h |
		h isAttachedToSceneGraph
			ifTrue: [self fillFollower: h]
			ifFalse: [h userData at: #stale put: true]]
]

{ #category : 'private' }
ImageMapViewer >> refreshPanes [
	"The window has moved: draw again every picture of this viewer that is still alive."
	panes ifNil: [^ self].
	panes copy do: [:p | p refresh]
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

{ #category : 'accessing' }
ImageMapViewer >> total [
	^ total
]
