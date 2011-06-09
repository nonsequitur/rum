module Rum
  class Key
    attr_accessor :name, :id, :aliases, :modifier
    
    def initialize name, aliases, id
      @name = name
      @id = id
      @aliases = aliases
      @modifier = false
    end
    
    def modifier?
      @modifier
    end

    def inspect
      "#<Key:#{name}>"
    end
  end

  class Layout
    attr_accessor :ids, :names, :aliases, :modifiers, :core_modifiers, \
                  :action_modifiers, :translations
    
    def initialize
      @ids = {}
      @names = {}
      @aliases = {}
      @modifiers = []
      @core_modifiers = {}
      # Windows-specific: Modifiers that trigger actions when pressed and released.
      @action_modifiers = {}
      @translations = {}
    end

    def keys
      @ids.values.uniq
    end

    def lookup_key id
      @ids[id]
    end

    def [] attribute
      @names[attribute] or @aliases[attribute] or @ids[attribute]
    end

    # Modifiers can have the names of other keys as aliases.
    # This allows for abbreviating 'ctrl shift enter'.do to 'c s enter'.do
    # Lookup the alias first to avoid matching normal keys.
    def modifier_lookup attribute
      if (key = @aliases[attribute] || @names[attribute]) and key.modifier?
        key
      end
    end

    def add *args, id
      id += 2**9 if args.delete :extended # Windows-specific magic value.
                                          # An explicit implementation might follow
      name = args.shift
      aliases = args
      key = Key.new(name, aliases, id)
      
      @ids[id] = key
      @names[name] = key
      aliases.each { |key_alias| @aliases[key_alias] = key }
      key
    end

    def alias key, key_alias
      key = self[key]
      @aliases[key_alias] = key
      key.aliases << key_alias
    end

    def rename from, to
      key = self[from]
      @names.delete from
      key.name = to
      @names[to] = key
    end

    def remap *from, to
      to = self[to]
      from.each { |key| @ids[self[key].id] = to }
    end

    def modifier key
      key = self[key]
      key.modifier = true
      @modifiers << key unless @modifiers.include? key
      key
    end

    def core_modifier key
      @core_modifiers[modifier(key)] = true
    end

    def action_modifier key
      @action_modifiers[modifier(key)] = true
    end
  end

  module Layouts
    def self.list
      layouts = methods(nil) - [:default_layout, :core, :basic, :list]
      layouts - Object.methods # Needed for MacRuby, methods(nil) doesn't work here.
    end
  end

  class Hotkey
    attr_accessor :key, :modifiers, :actions, :direction # todo: unveränderlich machen
    
    def initialize key, modifiers=[], fuzzy=false, actions=[]
      @key = key
      @modifiers = modifiers
      @fuzzy = fuzzy
      @actions = actions
      @direction = nil
    end

    def fuzzy?
      @fuzzy
    end

    def execute repeated
      @actions.each { |action| return true if action.execute(repeated) }
      false
    end

    def to_s
      (modifiers.dup << key).map(&:name).join ' '
    end
  end

  class Action
    attr_accessor :action, :condition, :hotkey, :location

    @@hook = nil
    
    def self.work_queue= queue
      @@work_queue = queue
    end

    def self.hook= proc
      @@hook = proc
    end

    def self.hook
      @@hook
    end
    
    def initialize(action, condition, repeated, location)
      @action = action
      @condition = condition
      @repeated = repeated
      @location = location
    end

    def execute repeated
      return false if not @action or repeated and not @repeated
      if not @condition or @condition.call
        if @@hook
          @@hook.call(self)
        else
          @@work_queue.enq @action
          true
        end
      end
    end

    def visit_definition
      @location.visit if @location
    end
  end

  # TODO: Needs refactoring.
  class HotkeySet
    attr_accessor :layout, :hotkeys, :modifiers, :down, :up, \
                  :up_fuzzy, :down_fuzzy, :modifier_hotkeys

    def initialize layout
      @layout = layout
      # All hotkeys that consist entirely of modifiers
      @modifier_hotkeys = {}
      @modifiers = layout.modifiers.sort_by &:id
      # All modifier combinations of all registered hotkeys
      @modifier_combinations = Hash.new(0)
      @up = {}
      @down = {}
      @up_fuzzy = {}
      @down_fuzzy = {}
    end

    def add_hotkey(string, action, condition, repeated, location)
      action = Action.new(action, condition, repeated, location)
      action.hotkey = hotkey_from_string(string)
      register(action)
    end

    def remove_hotkey string
      hotkey = hotkey_from_string(string)
      Rum.hotkey_set.unregister_conditionless_action(hotkey)
    end

    # Implement translations in terms of normal hotkeys.
    # TODO: Extending HotkeyProcessor to natively support translations might be a
    # simpler and more solid approach.
    def add_translation(string, to, condition, location)
      down_hotkey = hotkey_from_string(string)
      up_hotkey   = hotkey_from_string(string)
      down_hotkey.direction = :down
      up_hotkey.direction   = :up
      to_key = @layout[to]
      
      catch_modifier_up = proc do
        if down_hotkey.modifiers.include? @key
          send_key_event(to_key, false)
          remove_hook(catch_modifier_up)
        end
      end
      down_action = Action.new( lambda do
                                  send_key_event(to_key, true)
                                  Rum.hotkey_processor.add_hook(catch_modifier_up)
                                end,
                                condition, true, location)
      up_action   = Action.new( lambda do
                                  send_key_event(to_key, false)
                                  Rum.hotkey_processor.remove_hook(catch_modifier_up)
                                end,
                                condition, true, location)
      down_action.hotkey = down_hotkey
      up_action.hotkey   = up_hotkey
      register(down_action)
      register(up_action)
    end

    def hotkey_from_string str
      *modifier_aliases, key_alias = str.split(' ')
      fuzzy = !!modifier_aliases.delete('*')

      # Lookup modifiers
      modifiers = []
      modifier_aliases.each do |modifier_alias|
        if key = @layout.modifier_lookup(modifier_alias)
          modifiers << key
        else
          raise "Invalid modifier: #{modifier_alias}"
        end
      end
      modifiers = modifiers.sort_by &:id
      
      # Lookup key
      key = @layout[key_alias]
      raise "#{key_alias} is no valid key." unless key
      
      Hotkey.new(key, modifiers, fuzzy)
    end

    def register action
      hotkey = register_hotkey(action.hotkey)
      if action.condition
        hotkey.actions.unshift action # put actions with conditions first
      else
        # Only one conditionless action per hotkey
        unless last_action = hotkey.actions.last and last_action.condition
          hotkey.actions.pop
        end
        hotkey.actions << action
      end
      action
    end
    
    def unregister action
      if hotkey = action.hotkey
        hotkey.actions.delete(action)
        unregister_hotkey(hotkey) if hotkey.actions.empty?
        action
      end
    end

    def unregister_conditionless_action hotkey
      if hotkey = lookup_hotkey(hotkey) and action = hotkey.actions.last
        unregister action unless action.condition
      end
    end

    def get_dict(hotkey)
      if hotkey.fuzzy?
        dict = if hotkey.direction == :up
                 @up_fuzzy
               else
                 @down_fuzzy
               end
        dict = (dict[hotkey.key] ||= {})
        dict_key = hotkey.modifiers
      else
        dict_key = key_signature(hotkey)
        dict = if (dir = hotkey.direction and dir == :up) or \
                  (hotkey.key.modifier? and @modifier_combinations[dict_key] > 0)
                 @up
               else
                 @down
               end
      end
      [dict, dict_key]
    end
    
    def key_signature hotkey
      hotkey.modifiers.dup << hotkey.key
    end

    def lookup_hotkey hotkey
      dict, dict_key = get_dict(hotkey)
      dict[dict_key]
    end

    def register_hotkey hotkey
      dict, dict_key = get_dict(hotkey)
      existing_hotkey = dict[dict_key] and return existing_hotkey
      
      dict[dict_key] = hotkey
      if hotkey.key.modifier? # Modifier hotkeys aren't allowed to be fuzzy.
        @modifier_hotkeys[dict_key] = hotkey
      else
        register_modifier_combination(hotkey.modifiers)
      end
      hotkey
    end

    def unregister_hotkey hotkey
      dict, dict_key = get_dict(hotkey)
      if dict.delete(dict_key)
        if hotkey.key.modifier?
          @modifier_hotkeys.delete(hotkey)
        else
          unregister_modifier_combination(hotkey.modifiers)
        end
      end
    end

    def register_modifier_combination(modifiers)
      maybe_reregister_mod_hotkey(modifiers, 1, 0)
    end

    def unregister_modifier_combination(modifiers)
      maybe_reregister_mod_hotkey(modifiers, -1, 1)
    end

    # Example:
    # 1. The modifier hotkey 'ctrl shift' is the only registered hotkey.
    # 2. The hotkey 'ctrl shift a' gets registered.
    # Now the 'ctrl shift' hotkey needs to be re-registered to avoid
    # getting triggered while 'ctrl shift a' is pressed.
    #
    # Vice versa:
    # When all conflicting modifier combinations have been
    # unregistered, a modifier hotkey can be re-registered to trigger
    # instantly.
    #
    # This function keeps track of active modifier_combinations when
    # hotkeys ar added or removed. It re-registers corresponding
    # modifier hotkeys accordingly.
    def maybe_reregister_mod_hotkey(modifiers, change_count, threshold)
      count = @modifier_combinations[modifiers]
      if count == threshold and (mod_hotkey = @modifier_hotkeys[modifiers])
        unregister_hotkey(mod_hotkey)
        @modifier_combinations[modifiers] = count + change_count
        register_hotkey(mod_hotkey)
      else
        @modifier_combinations[modifiers] = count + change_count
      end
    end

    def lookup(down, signature)
      (down ? @down : @up)[signature]
    end

    def fuzzy_lookup(down, key, pressed_modifiers)
      if (hotkeys = (down ? @down_fuzzy : @up_fuzzy)[key])
        hotkeys.each do |modifiers, hotkey|
          return hotkey if modifiers.all? { |mod| pressed_modifiers[mod] }
        end
        nil
      end
    end
  end

  # TODO: Needs refactoring.
  class HotkeyProcessor
    attr_reader :layout, :pressed_modifiers, :hooks
    def initialize hotkey_set
      @hotkey_set = hotkey_set
      @modifiers = @hotkey_set.modifiers
      @layout = @hotkey_set.layout
      @pressed_modifiers = {}
      @was_executed = {}
      @key_signature = nil
      @hooks = []
      @pass_key = true
      
      @key = nil
      @last_key = nil
      @down = nil
      @last_event_up = nil
    end

    def add_hook(hook=nil, &block)
      hook ||= block
      @hooks.unshift hook
      hook
    end
    
    # Return removed hook.
    def remove_hook(hook)
      @hooks.delete hook
    end
    
    def key_signature key
      @modifiers.select { |modifier| @pressed_modifiers[modifier] } << key
    end

    def execute(down, repeated)
      (hotkey = @hotkey_set.lookup(down, @key_signature)                 \
       and hotkey.execute(repeated)) or
      (hotkey = @hotkey_set.fuzzy_lookup(down, @key, @pressed_modifiers) \
       and hotkey.execute(repeated))
    end

    def process_event event
      puts event
      @key = @layout.lookup_key(event.id)
      @down = event.down?
      unless @key
        puts "Unknown Key\n"
        return true
      end
      modifier = @key.modifier?

      # Skip generating unnecessary key_signatures
      if modifier and @last_event_up or @key != @last_key
        @key_signature = key_signature(@key)
      end
      @last_event_up = !@down
      
      print "[#{@key_signature.map { |key| key.name.capitalize }.join(', ')}]"
      print ' (again)' if @key == @last_key; puts
      
      if @down
        repeated = @was_executed[@key]
        eat = @was_executed[@key] = true if execute(true, repeated)
        if repeated
          eat = true
        elsif modifier # if repeated, the modifier has already been added to pressed_modifiers
          @pressed_modifiers[@key] = true
        end
      else #up
        @was_executed[@key] = true if execute(false, false)
        if modifier
          @pressed_modifiers[@key] = nil 
          if @layout.action_modifiers[@key] and \
            (!@pass_key or @was_executed[@key])
            inhibit_modifier_action
          end
        end
        eat = @was_executed.delete(@key)
      end
      
      @pass_key = if modifier
                    @layout.core_modifiers[@key]
                  else
                    !eat
                  end
      @hooks.dup.each { |hook| instance_eval &hook }
      @last_key = @key
      puts
      @pass_key    
    end
  end
end
