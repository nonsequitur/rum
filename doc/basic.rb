require 'rum'

'shift f1'.do { Rum.restart }

# If you use Emacs
require 'rum/apps'
'shift f2'.do { Emacs.eval '(rum-client)'; Emacs.activate }

Rum::Server.start
Rum.start
