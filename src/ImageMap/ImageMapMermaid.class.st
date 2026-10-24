"
I build the Mermaid sources of the diagrams in the ImageMap views, and I turn a Mermaid source into a Bloc element with Pele2svg (https://github.com/iriyak/pele2svg).

Pele2svg is optional. `ImageMapMermaid isAvailable` tells whether it is loaded. Without it, or when drawing fails (for example when Node.js is missing), `elementForSource:` answers a label with the reason, so the views that use me still open. Drawing starts an external process and takes about 0.4 s.

Each diagram has a `...SourceFor:` method (the Mermaid text) and an `...ElementFor:` method (the drawn element). Overview: `classesSourceFor:` (a sankey from the whole heap through kinds to the classes with at least 1%), `neighboursSourceFor:` (which kind follows which) and `sizesBytesSourceFor:` / `sizesObjectsSourceFor:` (bar charts per size class). Window: `classesSourceForSnapshot:` (the 14 classes with most bytes; KiB when the window is under 4 MiB). Diff: `classChangesSourceFor:` (bar chart). `sankeyStats:total:root:minShare:maxClasses:` is the sankey builder that both Classes diagrams share.
"
Class {
	#name : 'ImageMapMermaid',
	#superclass : 'Object',
	#category : 'ImageMap-Mermaid',
	#package : 'ImageMap',
	#tag : 'Mermaid'
}

{ #category : 'sources' }
ImageMapMermaid class >> chartTitle: aTitle unit: aUnit labels: labels values: values [
	^ self chartTitle: aTitle unit: aUnit labels: labels values: values horizontal: false
]

{ #category : 'sources' }
ImageMapMermaid class >> chartTitle: aTitle unit: aUnit labels: labels values: values horizontal: aBoolean [
	"A Mermaid bar chart (xychart-beta), vertical or horizontal. The labels are quoted. The value axis runs from a little below the smallest value (or 0) to a little above the biggest."
	| out top bottom |
	top := (values inject: 0 into: [:a :b | a max: b]) * 1.1 max: 1.
	bottom := (values inject: 0 into: [:a :b | a min: b]) * 1.1.
	out := WriteStream on: String new.
	out nextPutAll: 'xychart-beta'; nextPutAll: (aBoolean ifTrue: [' horizontal'] ifFalse: ['']); lf.
	out nextPutAll: '  title "', aTitle, '"'; lf.
	out nextPutAll: '  x-axis ['.
	labels do: [:l | out nextPut: $"; nextPutAll: l; nextPut: $"] separatedBy: [out nextPutAll: ', '].
	out nextPutAll: ']'; lf.
	out nextPutAll: '  y-axis "', aUnit, '" ', bottom floor printString, ' --> ', top ceiling printString; lf.
	out nextPutAll: '  bar ['.
	values do: [:v | out nextPutAll: ((v * 1.0) printShowingDecimalPlaces: 2)] separatedBy: [out nextPutAll: ', '].
	out nextPutAll: ']'; lf.
	^ out contents
]

{ #category : 'ui' }
ImageMapMermaid class >> classChangesElementFor: aDiff [
	^ (aDiff classChanges anySatisfy: [:r | (r at: 2) abs >= 1024])
		ifTrue: [self elementForSource: (self classChangesSourceFor: aDiff)]
		ifFalse: [(self messageElement: 'No class has changed by 1 KiB or more.') asScrollableElement]
]

{ #category : 'sources' }
ImageMapMermaid class >> classChangesSourceFor: aDiff [
	"A horizontal bar chart of the classes whose bytes changed most: the ten that grew most and the five that shrank most, in KiB. Changes under 1 KiB are left out; the table view has all of them."
	| changes grew shrank rows |
	changes := aDiff classChanges select: [:r | (r at: 2) abs >= 1024].
	grew := (changes select: [:r | (r at: 2) > 0]) first: ((changes count: [:r | (r at: 2) > 0]) min: 10).
	shrank := (changes select: [:r | (r at: 2) < 0]) last: ((changes count: [:r | (r at: 2) < 0]) min: 5).
	rows := grew, shrank.
	^ self chartTitle: 'Classes whose bytes changed most'
		unit: 'KiB'
		labels: (rows collect: [:r | | n | n := (r at: 1) name asString. n size > 28 ifTrue: [(n first: 27), '...'] ifFalse: [n]])
		values: (rows collect: [:r | (r at: 2) / 1024.0])
		horizontal: true
]

{ #category : 'ui' }
ImageMapMermaid class >> classesElementFor: anOverview [
	^ self elementForSource: (self classesSourceFor: anOverview)
]

{ #category : 'ui' }
ImageMapMermaid class >> classesElementForSnapshot: aSnapshot [
	"The diagram with a line above it that says which window it is."
	| box |
	aSnapshot cells isEmpty ifTrue: [^ (self messageElement: 'The window is empty.') asScrollableElement].
	box := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [:x | x horizontal fitContent. x vertical fitContent].
	box addChild: (self messageElement: 'Bytes by kind and class in '
		, aSnapshot cells size printString, ' objects, #', aSnapshot start printString, '..#', aSnapshot endIndex printString
		, ' (the 14 classes with most bytes are named)').
	box addChild: (self plainElementForSource: (self classesSourceForSnapshot: aSnapshot)).
	^ box asScrollableElement
]

{ #category : 'sources' }
ImageMapMermaid class >> classesSourceFor: anOverview [
	"The sankey of the whole heap: the classes that take at least 1% of it are named."
	^ self sankeyStats: anOverview classStats total: anOverview totalBytes root: 'Whole heap' minShare: 1/100 maxClasses: nil
]

{ #category : 'sources' }
ImageMapMermaid class >> classesSourceForSnapshot: aSnapshot [
	"The sankey of the objects in a window: the 14 classes with most bytes are named."
	^ self sankeyStats: aSnapshot classStats total: aSnapshot totalBytes root: 'This window' minShare: 0 maxClasses: 14
]

{ #category : 'ui' }
ImageMapMermaid class >> elementForSource: aMermaidString [
	"The same as plainElementForSource:, in a scrollable element."
	^ (self plainElementForSource: aMermaidString) asScrollableElement
]

{ #category : 'testing' }
ImageMapMermaid class >> isAvailable [
	"Is Pele2svg loaded?"
	^ Smalltalk includesKey: #Pele2svg
]

{ #category : 'private' }
ImageMapMermaid class >> kindClassDefsOn: aStream [
	"The Mermaid classDef lines that give each kind its colour: k_<kind>."
	ImageMapCell kinds do: [:k |
		aStream nextPutAll: '  classDef k_', k, ' fill:#', (ImageMapCell colorFor: k) asHexString, ',stroke:#444,color:#111'; lf]
]

{ #category : 'private' }
ImageMapMermaid class >> line: aSource to: aTarget bytes: n divisor: aDivisor on: aStream [
	"One row of a sankey diagram: source,target,value, with the bytes divided by aDivisor (1048576 for MiB, 1024 for KiB). Rows that round to zero are left out."
	| v |
	v := (n / aDivisor asFloat) printShowingDecimalPlaces: 2.
	v = '0.00' ifTrue: [^ self].
	aStream nextPutAll: aSource; nextPut: $,; nextPutAll: aTarget; nextPut: $,; nextPutAll: v; lf
]

{ #category : 'private' }
ImageMapMermaid class >> line: aSource to: aTarget bytes: n on: aStream [
	"A row of a sankey diagram in MiB."
	self line: aSource to: aTarget bytes: n divisor: 1048576 on: aStream
]

{ #category : 'ui' }
ImageMapMermaid class >> messageElement: aString [
	^ BrLabel new
		aptitude: BrGlamorousLabelAptitude;
		text: aString;
		padding: (BlInsets all: 12)
]

{ #category : 'ui' }
ImageMapMermaid class >> neighboursElementFor: anOverview [
	^ anOverview transitions
		ifNil: [self notScannedElement]
		ifNotNil: [self elementForSource: (self neighboursSourceFor: anOverview)]
]

{ #category : 'sources' }
ImageMapMermaid class >> neighboursSourceFor: anOverview [
	"A flowchart of the kinds: an arrow from kind A to kind B when an object of kind A is directly followed, in heap order, by an object of kind B at least 5% of the times. Each node says how often its kind is followed by the same kind."
	| out rows |
	out := WriteStream on: String new.
	rows := anOverview kindTransitionRows.
	out nextPutAll: 'flowchart LR'; lf.
	self kindClassDefsOn: out.
	rows do: [:r |
		out nextPutAll: '  n_', r kind, '["', r kind, '<br/>', r objects printString, ' objects<br/>followed by the same kind ', (r sameShare * 100) rounded printString, '%"]:::k_', r kind; lf].
	rows do: [:r |
		r nextShares do: [:a |
			(a value >= 0.05 and: [a key ~~ r kind]) ifTrue: [
				out nextPutAll: '  n_', r kind, ' -->|"', (a value * 100) rounded printString, '%"| n_', a key; lf]]].
	^ out contents
]

{ #category : 'ui' }
ImageMapMermaid class >> notScannedElement [
	^ (self messageElement: 'This overview was scanned before this was counted. Scan again with ImageMapOverview scan.') asScrollableElement
]

{ #category : 'ui' }
ImageMapMermaid class >> plainElementForSource: aMermaidString [
	"Answer an element with the diagram, or a label that says why it could not be drawn."
	^ self isAvailable
		ifFalse: [self messageElement: 'Pele2svg is not loaded. This diagram is drawn with Pele2svg (https://github.com/iriyak/pele2svg), which is optional.']
		ifTrue: [[(Smalltalk at: #Pele2svg) new asElement: aMermaidString]
			on: Error
			do: [:e | self messageElement: 'The diagram could not be drawn: ', e messageText]]
]

{ #category : 'sources' }
ImageMapMermaid class >> sankeyStats: stats total: aTotal root: aRootName minShare: aShare maxClasses: aCap [
	"A sankey diagram of bytes: aRootName, then the kinds, then the classes. stats maps a class to #(kind index, bytes, objects), as ImageMapOverview>>classStats does. A class is named when it has at least aShare of aTotal bytes, and at most aCap classes are named (nil: no limit), the biggest first. What is left of a kind goes to 'other <kind>' when it is at least 0.1% of the total, and to 'small remainders' otherwise. The unit is MiB, or KiB when the total is under 4 MiB. The height of the diagram follows the number of nodes in the last column; without it Mermaid draws every node one pixel high."
	| kinds total kindBytes rest named out divisor |
	kinds := ImageMapCell kinds.
	total := aTotal max: 1.
	divisor := total < (4 * 1048576) ifTrue: [1024] ifFalse: [1048576].
	kindBytes := Array new: kinds size withAll: 0.
	rest := Array new: kinds size withAll: 0.
	named := OrderedCollection new.
	stats keysAndValuesDo: [:aClass :v |
		kindBytes at: v first put: (kindBytes at: v first) + (v at: 2).
		(v at: 2) >= (aShare * total)
			ifTrue: [named add: aClass -> v]
			ifFalse: [rest at: v first put: (rest at: v first) + (v at: 2)]].
	named := named asSortedCollection: [:a :b | (a value at: 2) >= (b value at: 2)].
	(aCap notNil and: [named size > aCap]) ifTrue: [
		(named copyFrom: aCap + 1 to: named size) do: [:a |
			rest at: a value first put: (rest at: a value first) + (a value at: 2)].
		named := (named copyFrom: 1 to: aCap) asOrderedCollection].
	out := WriteStream on: String new.
	out nextPutAll: '%%{init: {"sankey": {"width": 900, "suffix": " ', (divisor = 1024 ifTrue: ['KiB'] ifFalse: ['MiB']), '", "height": ';
		print: ((named size + kinds size) * 28 max: 420);
		nextPutAll: '}}}%%'; lf.
	out nextPutAll: 'sankey-beta'; lf; lf.
	kinds doWithIndex: [:k :i |
		self line: aRootName to: k bytes: (kindBytes at: i) divisor: divisor on: out].
	named do: [:a |
		self line: (kinds at: a value first) to: a key name bytes: (a value at: 2) divisor: divisor on: out].
	kinds doWithIndex: [:k :i | | r |
		r := rest at: i.
		self line: k
			to: (r * 1000 >= total ifTrue: ['other ', k] ifFalse: ['small remainders'])
			bytes: r divisor: divisor on: out].
	^ out contents
]

{ #category : 'sources' }
ImageMapMermaid class >> sizesBytesSourceFor: anOverview [
	| rows |
	rows := anOverview sizeClassRows.
	^ self chartTitle: 'Bytes by size class (upper bound of the size, in bytes)'
		unit: 'MiB'
		labels: (rows collect: [:r | r shortLabel])
		values: (rows collect: [:r | r bytes / 1048576.0])
]

{ #category : 'ui' }
ImageMapMermaid class >> sizesElementFor: anOverview [
	| box |
	anOverview sizeCounts ifNil: [^ self notScannedElement].
	box := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [:x | x horizontal fitContent. x vertical fitContent].
	box addChild: (self plainElementForSource: (self sizesBytesSourceFor: anOverview)).
	box addChild: (self plainElementForSource: (self sizesObjectsSourceFor: anOverview)).
	^ box asScrollableElement
]

{ #category : 'sources' }
ImageMapMermaid class >> sizesObjectsSourceFor: anOverview [
	| rows |
	rows := anOverview sizeClassRows.
	^ self chartTitle: 'Objects by size class (upper bound of the size, in bytes)'
		unit: 'thousands of objects'
		labels: (rows collect: [:r | r shortLabel])
		values: (rows collect: [:r | r objects / 1000.0])
]
