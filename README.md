# Rum

A cross-platform hotkey and macro utility, running on Windows and Mac
OS.

Visit http://nonsequitur.github.io/rum for examples and a detailed
reference.

## Synopsis
```ruby
require 'rum'
Rum.layout.modifier 'caps'
'caps f1'.do { message 'foo' }
'caps shift f1'.do { message 'bar' }
Rum.start
```

## License
Rum is available under the MIT license
(http://www.opensource.org/licenses/mit-license.php)

Copyright 2010-2011, The Rum Project

### Licenses of software that is bundled with some Rum distributions
#### CocoaDialog
    CocoaDialog is Copyright © 2004, Mark A. Stratman <mark@sporkstorms.org>
    It is licensed under the GNU General Public License.
    http://cocoadialog.sourceforge.net/

#### Growl
    Copyright (c) The Growl Project, 2004
    All rights reserved.
    http://growl.info/documentation/developer/bsd-license.txt

#### AutoHotkey
    GNU General Public License
    http://www.autohotkey.com/docs/license.htm
