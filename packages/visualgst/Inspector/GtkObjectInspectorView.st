"======================================================================
|
| GtkObjectInspectorView class definition
|
======================================================================"

"======================================================================
|
| Copyright (c) 2013
| Gwenael Casaccio <gwenael.casaccio@gmail.com>,
|
|
| This file is part of VisualGST.
|
| Permission is hereby granted, free of charge, to any person obtaining
| a copy of this software and associated documentation files (the
| 'Software'), to deal in the Software without restriction, including
| without limitation the rights to use, copy, modify, merge, publish,
| distribute, sublicense, and/or sell copies of the Software, and to
| permit persons to whom the Software is furnished to do so, subject to
| the following conditions:
|
| The above copyright notice and this permission notice shall be
| included in all copies or substantial portions of the Software.
|
| THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
| EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
| MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
| IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
| CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
| TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
| SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
|
======================================================================"

Object subclass: GtkObjectInspectorView [
    | object model |

    GtkObjectInspectorView class >> openOn: anObject [
	<category: 'instance creation'>

	^ (super new)
	    object: anObject;
	    yourself
    ]

    object [
	<category: 'accessing'>
	
	^ object
    ]

    object: anObject [
	<category: 'accessing'>

	object := anObject.
    ]

    do: aBlock [ 
	<category: 'iterating'>

	aBlock value: 'self'.
        self object class allInstVarNames do: aBlock
    ]

    values [
	<category: 'accessing'>

	^Array streamContents: [:s | self do: [:value | s nextPut: value]]
    ]

    selectedValue: aString [
	<category: 'item selection'>

	| iter string instVar |
        ^ aString = 'self'
            ifTrue: [ self object ]
            ifFalse: [ self object
			instVarNamed: aString ]
    ]

    canDive [
	<category: 'testing'>

	^ true
    ]
]
