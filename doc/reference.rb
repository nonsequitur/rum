#### 1. Unicode
# Rum is unicode-compatible. The default encoding is UTF-8.

#### 2. Layouts
# Keyboard layout changes must take place before any hotkey definitions.

# Rum starts with a default QWERTY layout
Rum.layout #=> #<Rum::Layout:0xb99634 ... >

# Changing the layout
Rum.layout = Layouts.german

# Listing available layouts
Layouts.list

### Editing a layout
layout = Rum.layout

## Adding a modifier.
# Any key can be a modifier.
layout.modifier 'escape'

## Aliasing
layout.alias 'escape', 'esc'
# The original key...
layout['escape'] #=> #<Key:escape>
# ...can now be referenced by the alias
layout['esc']    #=> #<Key:escape>

## Renaming
layout.rename 'escape', 'foo'
layout['foo']  #=> #<Key:foo>

## Finding out the name of a key
# All keyboard activity is reported at the terminal.
# Switch to the Rum terminal window and press a key. 


### Advanced
## Adding a key
# add name, *aliases, id
layout.add 'my-key', 125
layout.add 'my-other-key', 'my-alias', 126

## Remapping
# Maps multiple key ids to a single key.
layout['lctrl'].id #=> 39
layout[39]         #=> #<Key:lctrl>
# remap from*, to
layout.remap 'lctrl', 'ctrl'
layout[39] #=> #<Key:ctrl>

## Core modifiers
# Core modifiers, unlike standard modifiers, are always passed on to
# the Operating System.
# Shift, Ctrl, etc. are core modifiers.
layout.core_modifier 'escape' # Sets a core modifier.



#### 2. Hotkeys
## The basics
'modifiers hotkey'.do { action }
'ctrl shift w'.do { active_window.close }
'f1'.do { type 'hello' }
# The last statement can be abbreviated:
'f1'.do 'hello'

## Hotkey conditions
# Restrict hotkeys to trigger only when certain
# conditions are met.
'hotkey'.do(condition) { action }
'f1'.do( lambda { rand(3) == 1 } ) { puts 'win!' }

## Fuzzy hotkeys
# The wildcard '*' forces a hotkey to trigger regardless of
# other modifiers being pressed.
'* shift a'.do { action } # would be triggered by 'ctrl shift option a'

# Normal, non-fuzzy hotkeys take precedence over fuzzy hotkeys.

## No-Repeat
# Don't trigger on repetitive key-down events that are spawned when a key is
# held down for a certain time:
'f1'.do(:no_repeat) { action }

## Modifier hotkeys
# Hotkeys that consist solely of modifiers.
'ctrl'.do { action }
'ctrl shift'.do { action }
# The modifiers used in modifier-only hotkeys can be part of another
# hotkey.
# In this case, modifier hotkeys trigger on key-up and only when
# no other key has been pressed in the meantime.
# Otherwise, they trigger instantly.

# Example, assuming 'caps' is a valid modifier:
'caps'.do { action }  # Hotkey 1) - Triggers on key-down.
'caps a'.do { action} # Hotkey 2) - Conflicting hotkey.
                      # Forces hotkey 1) to now trigger on key-up.

## Translations
# Translations allow keys or key combinations to act as another key.

'ctrl a'.translate 'up' # 'up' is pressed as soon as 'ctrl a' is pressed.
                        # 'up' is released when either 'ctrl' or 'a' are released.

# Translations are usually combined with fuzzy hotkeys
'* ctrl a'.translate 'up' # would be triggered by e.g. 'ctrl shift a'

# Example: Move the 'up' and 'down' cursor keys to the home row
'* caps j'.translate 'down'
'* caps k'.translate 'up'


## Unregistering and re-registering hotkeys

# All methods concerned with registering or unregistering hotkeys
# return actions that can be, again, registered or unregistered.
action = 'ctrl a'.do { do_stuff } #=> #<Rum::Action...>
action.unregister #=> #<Rum::Action...>
action.register   #=> #<Rum::Action...>

# Unregistering the conditionless action of a hotkey
action = 'ctrl a'.unregister
# Actions with conditions...
'ctrl a'.do(condition) { do_stuff }
# ... can't be unregistered this way



#### 3. Keyboard

### Caveat: Not yet available on the Mac.

# Generates keystrokes.
Keyboard.type 'hi'
# The 'Keyboard.' prefix can be omitted.
type 'hello world'

# Some keys have multi-character names or aliases.
# Wrap them in parentheses.
type 'foo(tab)bar'

# Pause for a short while between sending characters.
type 'hello', :slow

## Sending key combinations
# To send key combinations, enclose multiple keys within
# parentheses and nest them. (S-expressions!)
type '(ctrl (shift hi))' # sends ctrl-down, shift-down, hi, shift-up, ctrl-up

# Backslash (\) acts as an escape character
type '\(' # sends a (

## Send string literally, without syntax interpretation
type! '(in brackets)'

## Translations
# Some keys are translated into key combinations.
type 'A' # sends '(shift a)'
# See Rum.layout.translations

## Sending single keyboard events
System.keydown 'a'
System.keyup 'a'
# In a future release, this might be integrated
# into the main keyboard syntax, like:
type '(keydown a)'

## Auto-release
# Pressed core modifiers are released before
# keyboard input is generated.
# You can safely do the following:
'ctrl a'.do { type 'w' } # 'ctrl' gets released before 'w' is sent.

# Provide the :blind flag to bypass auto-releasing
'ctrl a'.do { type 'w', :blind } # 'ctrl' might still be pressed when 'w' is sent.


## Windows-specific: Extended keys
# Sends 'alt' with the 'extended' flag set.
type '(alt-extended)'



#### 3. Gui
## Messages
# Prints a non-disruptive notification when Growl is enabled,
# falls back to alert (see below)  otherwise
message 'text'
message 'text', 'title'
# Sticky: Keep the message from fading out after a few seconds
message 'hello', :sticky
# Callback: Do something when the user clicked on the message
message('click me') { message 'clicked!' }

## Alerts
# Shows a focus-stealing 'ok, cancel' message box, prompting for a response
alert 'message' # returns true or false
alert 'message', 'title'

## Input boxes
read # returns the response or an empty string
read 'hi, how are you?'
read default: 'default input'
read 'hi, how are you?', default: 'splendid', title: 'greeting'

## Choose from candidates
# This one should launch a quicksilver-like fuzzy selection Gui.
choose 'choose one', ['red', 'blue', 'yellow']
# TODO: Currently this is only supported via Emacs/Ido.
# Falls back to an ugly combobox for non Emacs users.
# Which selection GUIs are there already on the Mac and on
# Windows that could be harnessed?

# TODO: Emacs
Gui.use Gui::EmacsInteraction

## Open (text) files
open_file path
# Using a text editor ...
Gui.use Textmate, :open_file
Gui.use Emacs, :open_file
# ... enables jumping to a specific line
open_file 'foo.txt', 24
# You may re-define open_file to fit your specific needs.

## Open URLs
browse 'example.com' # HTTP is implicit, unless another protocol is specified

## Show directories or files in your file manager
goto 'foo'

## Gui Module
# The above methods are part of the Gui module and may also be called explicitly:
Gui.message
Gui.read
...


#### 4. Get selected text
### Caveat: Not yet available on the Mac.
# Grabs the currently selected text.
get_selection # returns the current selection or nil


#### 5. Clipboard
### Caveat: Not yet available on the Mac.
# Retrieves the clipboard contents as text.
Clipboard.get # Always returns a string

# Sets the clipboard.
Clipboard.set 'hello'

# Sends a 'copy to clipboard' keyboard shortcut
# and waits until the clipboard changes.
Clipboard.copy # returns true if successful

# Sends a 'paste' keyboard shortcut.
Clipboard.paste

# Append the result of get_selection as a new line
# to the current clipboard content.
Clipboard.get #=> "foo"
Clipboard.append
Clipboard.get #=> "foo\nbar", assuming 'bar' was selected.

# Run a block while preserving the clipboard contents.
Clipboard.set 'foo'
Clipboard.preserve { Clipboard.set 'bar' }
Clipboard.get #=> "foo"


#### 6. More methods
## Waiting
# Wait until condition is true. Times out after 5 seconds, updates every 0.01 seconds.
wait { condition } #=> False when timed-out. Otherwise: true

# Set a 10 second timeout and a 0.5 second update interval.
wait(10, 0.5) { my_window.active? }

## Run a command in a separate terminal window.
spawn_in_terminal command, *args
spawn_in_terminal 'ruby', '-e', 'puts Time.now'
# Close the window if the command exits without errors.
spawn_in_terminal 'ruby', '-e', 'puts "Hello!"; sleep 2', :close_if_successful

## Open documents, run programs
# Wraps the 'open' command on the Mac and ShellExecute on Windows.
start file, *args

## Applescript
applescript 'tell application "System Events"
               activate
               display dialog "Hello!"
             end tell'

# The last three methods are part of the System module and may be
# called explicitly:
System.spawn_in_terminal
System.start
System.applescript

#### 6. Rum's threading model
# Rum employs one worker thread that executes all hotkey actions
# sequentially.
# Errors during execution are automatically reported via Gui.message.

# If you have a long running action that may run in parallel with
# other actions call 'Rum.switch_worker_thread'. Action execution is
# then resumed in another thread.
'ctrl a'.do { Rum.switch_worker_thread; long_running_stuff }

# The following is also possible...
'ctrl a'.do { Thread.new { long_running_stuff } }
# ... but errors in 'long_running_stuff' won't be implicitly
# caught and reported by Rum.

# When you call Gui.read, Gui.alert or Gui.print
# then Rum.switch_worker_thread is automatically run.

#### 5. Help, introspection
# Prompts you to enter a hotkey and then jumps to its
# definition via Gui.open_file.
Rum.show_hotkey
# (Requires you to register your text-editor, see Gui.open_file above.)

# Asks you to enter an arbitrary hotkey and inserts a hotkey
# definition snippet via Keyboard.type.
# When 'shift a' is pressed, 'shift a'.do { } is inserted.
Rum.snippet

# Reads a hotkey and passes it to the block.
# (Internally used by Rum.snippet)
Rum.read_key { |hotkey| do_stuff_with hotkey }

# Shows information about windows as they become active.
WindowInfo.start

# Opens this reference in a text editor
Rum.reference


#### 5. Restarting, server
# Restart the current Rum configuration.
Rum.restart 

# Start the server. This allows for connections to the
# Rum process via rum-client.
Rum::Server.start


#### 6. Windows

### Caveat: Not yet available on the Mac.

## Retrieving windows
active_window #=> #<Rum::System::Window...>
# Traversing all active windows:
active_windows #=> #<Enumerator:...>
active_windows.each { |window| window.close if window.title.empty? }
active_windows.map &:title

## Window Matchers
# WindowMatchers serve as a shorthand for using active_windows.find:
matcher = Window[title: /ruby/, class_name: 'MozillaUIWindowClass']
# or shorter:
matcher = Window[/ruby/, 'MozillaUIWindowClass']
matcher      #=> #<Rum::System::WindowMatcher...>
matcher.find #=> #<Rum::System::Window...>
Window[class_name: 'Emacs'].find
# The first matching window is returned.
# WindowMatcher attributes differ between platforms.
# The Windows version shown here supports 'title' and 'class_name'.
# String arguments are checked for equality with the corresponding
# window attributes, Regex arguments require a match.

## Window objects
w = active_window #=> #<Rum::System::Window:...>
w == active_window #=> true
w.show # returns true if successful
w.minimize
w.maximize
w.toggle_always_on_top
w.title #=> "A window title"
w.class_name #=> "Chrome_WidgetWin_0"
w.close
w.kill_task # kills the task associated with the window


#### 7. Apps
# Integrates prominent applications into Rum.
require 'rum/apps'

## App objects
app = Emacs #=> #<Rum::App:...>
# Start app or bring it to the front when it's already running.
# This works for all apps.
# Returns true when the app could be activated instantly.
app.activate #=> true

## Emacs
Emacs.eval '(message "hi")' #=> "\"hi\""
Emacs.eval '(* 3 3)' #=> "9"

# Eval in the current buffer context.
Emacs.eval_in_user_buffer = true
Emacs.eval 'default-directory' #=> "~/current_buffer_dir/"
Emacs.eval '(idle-highlight-mode t)' # Turns on a minor mode in the current buffer.

# Set this on Windows to allow Emacs.activate
# to start Emacs when it's not running.
Emacs.path = 'path/to/runemacs'
 
