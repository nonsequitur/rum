## A short survey of the main features
## This file can be found at rum_dir/doc/example.rb

require 'rum'

# 1. Set up additional modifiers that can then
# be used in hotkey definitions.
# Any key can be a modifier
Rum.layout.modifier 'caps'
Rum.layout.modifier 'escape'

# 2. Hotkey definitions
'ctrl a'.do { puts 'foo' }
# Hotkeys may consist solely of modifiers
'caps'.do { puts 'bar' }
'caps ctrl'.do { puts 'bar' }
# Hotkey conditions
'f1'.do( lambda { rand(2) == 1 } ) { puts 'win!' }
# Fuzzy hotkeys, trigger regardless of other modifiers being pressed
'* ctrl b'.do { puts 'hi' }
# Translations
'* caps j'.translate 'down'

# 3. Gui
message 'message'
read 'hi, how are you?' # Input box

# 4. Keyboard, send keypresses
type 'hello'
type '(ctrl (shift a))' # Key combinations

# 5. Help and introspection
# Prompts you to enter a hotkey and then jumps to its
# definition in your text editor.
'shift f2'.do { Rum.visit_hotkey }

# Asks you to enter an arbitrary hotkey and inserts a hotkey
# definition snippet.
'shift f3'.do { Rum.snippet }

# Restarts Rum.
'shift f1'.do { Rum.restart }


# 6. Integrate external features
Gui.use Gui::Growl

# Set up a text-editor for opening files
require 'rum/apps'
Gui.use Textmate, :open_file
# Or
Gui.use Emacs, :open_file

# 7. Start the server. You can now connect to the
# Rum process via rum-client.
Rum::Server.start

# 8. Start rum
Rum.start
