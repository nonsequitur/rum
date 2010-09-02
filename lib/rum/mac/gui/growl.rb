module Rum
  module Gui
    module Growl
      class Notifier
        def initialize application_name, notification_name
          @application_name  = application_name
          @notification_name = notification_name
          @callbacks = {}
          GrowlApplicationBridge.setGrowlDelegate(self)
        end
        
        def registrationDictionaryForGrowl
          notifications = [@notification_name]
          { TicketVersion: 1,  AllNotifications: notifications,
            DefaultNotifications: notifications,  ApplicationId: ''}
        end

        def applicationNameForGrowl
          @application_name
        end

        def growlNotificationWasClicked click_context
          @callbacks[click_context].call
        end

        def notify(title, description, sticky, callback)
          if callback
            click_context = callback.object_id
            @callbacks[click_context] = callback
          end
          GrowlApplicationBridge.notifyWithTitle(title.to_s,
                                                 description: description.to_s,
                                                 notificationName: @notification_name,
                                                 iconData: nil,
                                                 priority: 0,
                                                 isSticky: !!sticky,
                                                 clickContext: click_context)
        end
      end

      def self.auto_setup
        framework File.join(File.dirname(__FILE__), 'Growl.framework')
        @@notifier = Notifier.new('Rum', 'Notification')
      end
      
      private
      
      def message_backend(text, title, sticky, callback)
        title ||= 'Rum' # Mac Growl needs a title
        @@notifier.notify(title, text, sticky, callback)
      end
    end
  end
end
