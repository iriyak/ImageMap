"
I am the Metacello baseline of ImageMap. Load ImageMap with `Metacello new repository: 'github://iriyak/ImageMap:main/src'; baseline: 'ImageMap'; load`.

The default group also loads Pele2svg (github://iriyak/pele2svg, with its tests), which draws the Mermaid diagrams of the Classes, Neighbours, Sizes and Class changes views and of References. Pele2svg needs Node.js, and `Pele2svg installDependencies` has to be run once after loading it.

ImageMap needs Glamorous Toolkit (Bloc, Brick and Phlow), which this baseline does not declare, so load it into a GT image. `BaselineOfImageMap loadLepiter` adds the lepiter directory of the cloned repository to the default Lepiter database.
"
Class {
	#name : 'BaselineOfImageMap',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfImageMap',
	#package : 'BaselineOfImageMap'
}

{ #category : 'loading' }
BaselineOfImageMap class >> loadLepiter [
	IceRepository registry  
		detect: [ :aRepository |
			aRepository name = 'ImageMap' ]
		ifFound: [ :aRepository | 
			| defaultDatabase currentProperties |
			defaultDatabase := LeDatabasesRegistry defaultLogicalDatabase.
			currentProperties := defaultDatabase properties.
			currentProperties addRegisteredDirectory: aRepository repositoryDirectory / 'lepiter'.
			defaultDatabase reload ]
		ifNone: [
			self inform: 'Repository not found.' ]
]

{ #category : 'baseline' }
BaselineOfImageMap >> baseline: spec [
	<baseline>
		^ spec for: #common do: [
			spec baseline: 'Pele2svg' with: [
				spec repository: 'github://iriyak/pele2svg:main/src'].
			spec package: 'ImageMap'.
			spec group: 'default' with: #('ImageMap' 'Pele2svg')
		]
]
