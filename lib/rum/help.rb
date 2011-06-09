module Rum
  def self.reference
    reference = File.join(File.dirname(__FILE__), '..', '..',
                          'doc', 'reference.rb')
    Gui.open_file reference
  end
  
  def self.read_key &proc
    KeyReader.start(hotkey_processor, proc)
  end

  def self.visit_hotkey
    read_key { |hotkey| Gui.message "'#{hotkey}' not active" }
    Action.hook = lambda do |action|
      KeyReader.remove_hooks
      action.visit_definition or Gui.message "Definition location unkown."
      # Must return true for the key that triggered the action to be
      # retained by the processor.
      true
    end
  end

  def self.print_next_hotkey
    read_key { |hotkey| Gui.message hotkey }
  end

  def self.snippet
    Gui.message 'Enter hotkey!'
    read_key do |hotkey|
      snippet = "'#{hotkey}'.do {  }"
      Keyboard.type! snippet
      Keyboard.type '(left)(left)'
    end
  end

  module KeyReader
    extend self
    attr_accessor :pressed_modifiers
    
    Hook = proc do
      @pass_key = false
      if @key.modifier?
        if @down
          KeyReader.pressed_modifiers << @key
        elsif seen_key = KeyReader.pressed_modifiers.delete(@key)
          if @key == @last_key
            KeyReader.stop(@key, @pressed_modifiers) 
          elsif @pressed_modifiers.values.compact.empty?
            KeyReader.stop
          end
        else
          @pass_key = true
        end
      elsif @down and not @was_executed[@key]
        KeyReader.stop(@key, @pressed_modifiers)
      end
    end
    
    def start(hotkey_processor, proc)
      @hotkey_processor = hotkey_processor
      @proc = proc
      @pressed_modifiers = []
      add_hooks
    end

    def stop key=nil, modifiers=nil
      if key
        modifiers = modifiers.keys.select { |key| modifiers[key] }
        key = Hotkey.new(key, modifiers)
      end
      remove_hooks
      @proc.call(key)
    end

    def add_hooks
      @hotkey_processor.add_hook Hook
      Action.hook = lambda { |action| } # Ignore Actions.
    end

    def remove_hooks
      @hotkey_processor.remove_hook Hook
      Action.hook = nil
    end
  end

  module WindowInfo
    module_function
    
    def start
      return if @thread
      register_stop_key
      @stop = false
      @thread = Thread.new do
        new = old = nil
        loop do
          break if @stop
          new = active_window
          if new != old
            Gui.message new.report
            old = new
          end
          sleep 0.1
        end
        Clipboard.set new.report
        Gui.message 'Window Info stopped.'
        @thread = nil
      end
    end

    StopKey = 'escape'

    def register_stop_key
      @old_action = StopKey.unregister
      StopKey.do { WindowInfo.stop }
      Gui.message "Press '#{StopKey}' to stop WindowInfo."
    end

    def stop
      return unless @thread
      @stop = true
      if @old_action
        @old_action.register
      else
        StopKey.unregister
      end
    end
  end
end
